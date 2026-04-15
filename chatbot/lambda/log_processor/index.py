"""
Log Processor Lambda
--------------------
Triggered by SQS. Reads conversation log entries and persists them to DynamoDB
for compliance auditing and conversation history review.

Each SQS message body is a JSON object with:
    conversation_id  str   Caller-supplied conversation ID
    session_id       str   Bedrock session ID (may differ on first turn)
    question         str   Employee's original question
    answer           str   LLM-generated answer
    sources          list  S3 URIs of retrieved source documents
    timestamp        str   ISO-8601 UTC timestamp of the original request
    request_id       str   Lambda request ID for correlation

DynamoDB schema:
    PK: conversation_id  (partition key)
    SK: timestamp        (sort key — ISO-8601 UTC, enables time-range queries)
"""

import json
import logging
import os
# FIX #4 — timedelta moved to top-level import (was inside conditional block)
from datetime import datetime, timedelta, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

DYNAMODB_TABLE_NAME = os.environ["DYNAMODB_TABLE_NAME"]
LOG_TTL_DAYS        = int(os.environ.get("LOG_TTL_DAYS", "365"))

_dynamodb = None


def _table():
    global _dynamodb
    if _dynamodb is None:
        _dynamodb = boto3.resource("dynamodb").Table(DYNAMODB_TABLE_NAME)
    return _dynamodb


# ── Handler ───────────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Process a batch of SQS records.
    Uses ReportBatchItemFailures — failed message IDs are returned so SQS retries
    them individually rather than reprocessing the entire batch.
    """
    failures = []

    for record in event.get("Records", []):
        message_id = record.get("messageId", "unknown")
        try:
            entry = json.loads(record["body"])
            _persist_log(entry)
            logger.info(
                "Persisted log | messageId=%s | conversationId=%s",
                message_id,
                entry.get("conversation_id"),
            )
        except Exception as exc:
            logger.error(
                "Failed to process message | messageId=%s | error=%s",
                message_id,
                exc,
                exc_info=True,
            )
            failures.append({"itemIdentifier": message_id})

    if failures:
        logger.warning("%d message(s) failed — reporting for SQS retry", len(failures))

    return {"batchItemFailures": failures}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _persist_log(entry: dict):
    """Write a single conversation log entry to DynamoDB."""
    conversation_id = entry.get("conversation_id") or "unknown"
    timestamp       = entry.get("timestamp") or datetime.now(timezone.utc).isoformat()

    item = {
        "conversation_id": conversation_id,
        "timestamp":       timestamp,
        "session_id":      entry.get("session_id", ""),
        "question":        entry.get("question", ""),
        "answer":          entry.get("answer", ""),
        "sources":         entry.get("sources", []),
        "request_id":      entry.get("request_id", ""),
        "logged_at":       datetime.now(timezone.utc).isoformat(),
    }

    if LOG_TTL_DAYS > 0:
        expires_dt      = datetime.now(timezone.utc) + timedelta(days=LOG_TTL_DAYS)
        item["expires_at"] = int(expires_dt.timestamp())

    try:
        _table().put_item(
            Item=item,
            # Idempotency guard: do not overwrite an entry already persisted
            ConditionExpression=(
                "attribute_not_exists(conversation_id) AND attribute_not_exists(#ts)"
            ),
            ExpressionAttributeNames={"#ts": "timestamp"},
        )
    except ClientError as exc:
        # FIX #2 — ConditionalCheckFailedException means the item was already
        # persisted on a previous attempt (SQS retry). Treat as success so the
        # message is not re-queued and eventually moved to the DLQ.
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            logger.info(
                "Duplicate message skipped — already persisted | conversationId=%s timestamp=%s",
                conversation_id,
                timestamp,
            )
            return
        raise
