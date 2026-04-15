"""
Chat Handler Lambda
-------------------
Entry point for the bank employee chatbot API.

Request body (JSON):
    conversation_id  str   Bedrock session ID from a previous turn (omit for new conversation)
    question         str   Employee's question (required, max QUESTION_MAX_LENGTH chars)

Response body (JSON):
    conversation_id  str   Bedrock session ID — pass back on next request to continue the chat
    answer           str   LLM-generated answer grounded in the knowledge base
    sources          list  S3 URIs of retrieved documents that informed the answer

Error responses:
    400  missing/invalid input or invalid request parameters
    410  session expired — frontend should start a new conversation
    500  unexpected server error
"""

import json
import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Lazy-initialised clients (reused across warm invocations)
_bedrock_agent_runtime = None
_sqs_client = None


def _bedrock():
    global _bedrock_agent_runtime
    if _bedrock_agent_runtime is None:
        _bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")
    return _bedrock_agent_runtime


def _sqs():
    global _sqs_client
    if _sqs_client is None:
        _sqs_client = boto3.client("sqs")
    return _sqs_client


# ── Environment variables ────────────────────────────────────────────────────
KNOWLEDGE_BASE_ID   = os.environ["KNOWLEDGE_BASE_ID"]
MODEL_ARN           = os.environ["MODEL_ARN"]
SQS_QUEUE_URL       = os.environ["SQS_QUEUE_URL"]
KB_NUM_RESULTS      = int(os.environ.get("KB_NUM_RESULTS", "5"))
GUARDRAIL_ID        = os.environ.get("GUARDRAIL_ID", "")       # FIX #7
GUARDRAIL_VERSION   = os.environ.get("GUARDRAIL_VERSION", "DRAFT")
# FIX #6 — CORS origin from environment, not hardcoded wildcard
CORS_ALLOWED_ORIGIN = os.environ.get("CORS_ALLOWED_ORIGIN", "*")
# FIX #12 — configurable input length guard
QUESTION_MAX_LENGTH = int(os.environ.get("QUESTION_MAX_LENGTH", "2000"))

# ── System prompt ─────────────────────────────────────────────────────────────
SYSTEM_PROMPT = (
    "You are a professional assistant for bank branch employees. "
    "Your role is to help employees find accurate information about internal bank policies, "
    "procedures, compliance regulations, and operational documents. "
    "Always provide professional, precise responses based solely on the retrieved documents. "
    "If the requested information is not found in the knowledge base, clearly state that "
    "and suggest contacting the relevant department. "
    "Never fabricate information, provide personal financial advice to customers, "
    "or reference documents that are not present in the search results."
)

# $search_results$ and $query$ are substituted by Bedrock at inference time
PROMPT_TEMPLATE = (
    f"{SYSTEM_PROMPT}\n\n"
    "Use the following retrieved documents to answer the employee's question.\n\n"
    "Retrieved documents:\n$search_results$\n\n"
    "Employee question: $query$\n\n"
    "Provide a clear, professional answer based on the documents above. "
    "If the documents do not contain a definitive answer, say so explicitly."
)


# ── Handler ───────────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    logger.info(
        "Request received | requestId=%s | path=%s",
        context.aws_request_id,
        event.get("path", "/chat"),
    )

    body = _parse_body(event.get("body"))
    if body is None:
        return _response(400, {"error": "Request body must be valid JSON"})

    question        = body.get("question", "").strip()
    conversation_id = body.get("conversation_id", "").strip()

    if not question:
        return _response(400, {"error": "'question' is required"})

    # FIX #12 — guard against runaway input costs
    if len(question) > QUESTION_MAX_LENGTH:
        return _response(400, {
            "error": f"'question' exceeds maximum length of {QUESTION_MAX_LENGTH} characters"
        })

    try:
        kb_response = _bedrock().retrieve_and_generate(**_build_request(conversation_id, question))
    except ClientError as exc:
        code    = exc.response["Error"]["Code"]
        message = exc.response["Error"].get("Message", "")

        # FIX #10 — distinguish session expiry from generic validation errors
        if code == "ValidationException" and "session" in message.lower():
            logger.warning("Session expired | sessionId=%s", conversation_id)
            return _response(410, {
                "error": "session_expired",
                "message": "This conversation session has expired. Start a new conversation by omitting conversation_id.",
            })

        if code in ("ValidationException", "ResourceNotFoundException"):
            logger.error("Bedrock client error [%s]: %s", code, exc)
            return _response(400, {"error": "Invalid request parameters"})

        logger.error("Bedrock ClientError [%s]: %s", code, exc, exc_info=True)
        return _response(500, {"error": "Internal server error"})
    except Exception as exc:
        logger.error("Unexpected error: %s", exc, exc_info=True)
        return _response(500, {"error": "Internal server error"})

    answer     = kb_response["output"]["text"]
    session_id = kb_response.get("sessionId", conversation_id)
    sources    = _extract_sources(kb_response.get("citations", []))

    logger.info("Answer generated | sessionId=%s | sources=%d", session_id, len(sources))

    # Fire-and-forget — logging failure must NOT affect the user response
    _enqueue_log(
        conversation_id=conversation_id or session_id,
        session_id=session_id,
        question=question,
        answer=answer,
        sources=sources,
        request_id=context.aws_request_id,
    )

    return _response(200, {
        "conversation_id": session_id,
        "answer": answer,
        "sources": sources,
    })


# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_body(raw_body):
    if not raw_body:
        return {}
    try:
        return json.loads(raw_body)
    except (json.JSONDecodeError, TypeError):
        return None


def _build_request(conversation_id: str, question: str) -> dict:
    """Build the retrieve_and_generate API payload."""
    generation_config = {
        "promptTemplate": {"textPromptTemplate": PROMPT_TEMPLATE},
        "inferenceConfig": {
            "textInferenceConfig": {
                "maxTokens": 2048,
                "temperature": 0.0,
                "topP": 1.0,
            }
        },
    }

    # FIX #7 — attach guardrail when configured
    if GUARDRAIL_ID:
        generation_config["guardrailConfiguration"] = {
            "guardrailId":      GUARDRAIL_ID,
            "guardrailVersion": GUARDRAIL_VERSION,
        }

    params = {
        "input": {"text": question},
        "retrieveAndGenerateConfiguration": {
            "type": "KNOWLEDGE_BASE",
            "knowledgeBaseConfiguration": {
                "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                "modelArn":        MODEL_ARN,
                "retrievalConfiguration": {
                    "vectorSearchConfiguration": {"numberOfResults": KB_NUM_RESULTS}
                },
                "generationConfiguration": generation_config,
            },
        },
    }

    if conversation_id:
        params["sessionId"] = conversation_id

    return params


def _extract_sources(citations: list) -> list:
    """Return a de-duplicated list of S3 URIs from Bedrock citations."""
    seen, sources = set(), []
    for citation in citations:
        for ref in citation.get("retrievedReferences", []):
            uri = ref.get("location", {}).get("s3Location", {}).get("uri")
            if uri and uri not in seen:
                seen.add(uri)
                sources.append(uri)
    return sources


def _enqueue_log(*, conversation_id, session_id, question, answer, sources, request_id):
    """Send a log entry to SQS for async persistence. Swallows exceptions."""
    try:
        _sqs().send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "conversation_id": conversation_id,
                "session_id":      session_id,
                "question":        question,
                "answer":          answer,
                "sources":         sources,
                "timestamp":       datetime.now(timezone.utc).isoformat(),
                "request_id":      request_id,
            }),
            MessageAttributes={
                "conversation_id": {
                    "StringValue": conversation_id,
                    "DataType":    "String",
                }
            },
        )
        logger.info("Log entry queued | conversationId=%s", conversation_id)
    except Exception as exc:
        logger.warning("Failed to enqueue log entry: %s", exc)


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            # FIX #6 — CORS origin from env variable
            "Access-Control-Allow-Origin": CORS_ALLOWED_ORIGIN,
        },
        "body": json.dumps(body),
    }
