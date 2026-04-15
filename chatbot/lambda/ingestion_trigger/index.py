"""
Ingestion Trigger Lambda
------------------------
FIX #13 — Automatically starts a Bedrock Knowledge Base ingestion job
whenever a document is created or deleted in the KB S3 bucket.

Triggered by: S3 ObjectCreated:* and ObjectRemoved:* events.

If an ingestion job is already running (ConflictException), the event is
logged and skipped — Bedrock will pick up the latest S3 state on the
next ingestion job, so no data is lost.
"""

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID    = os.environ["DATA_SOURCE_ID"]

_bedrock_agent = None


def _bedrock():
    global _bedrock_agent
    if _bedrock_agent is None:
        _bedrock_agent = boto3.client("bedrock-agent")
    return _bedrock_agent


def lambda_handler(event, context):
    records = event.get("Records", [])
    logger.info(
        "S3 event received | records=%d | requestId=%s",
        len(records),
        context.aws_request_id,
    )

    for record in records:
        bucket = record.get("s3", {}).get("bucket", {}).get("name", "unknown")
        key    = record.get("s3", {}).get("object", {}).get("key", "unknown")
        event_name = record.get("eventName", "unknown")
        logger.info("Processing S3 event | event=%s | bucket=%s | key=%s", event_name, bucket, key)

    try:
        response = _bedrock().start_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
        )
        job_id = response["ingestionJob"]["ingestionJobId"]
        status = response["ingestionJob"]["status"]
        logger.info("Started ingestion job | jobId=%s | status=%s", job_id, status)
        return {"ingestionJobId": job_id, "status": status}

    except ClientError as exc:
        code = exc.response["Error"]["Code"]
        if code == "ConflictException":
            # An ingestion job is already in progress. Bedrock will reflect the
            # latest S3 state when it completes, so this event is not lost.
            logger.info(
                "Ingestion job already in progress — skipping | "
                "knowledgeBaseId=%s | dataSourceId=%s",
                KNOWLEDGE_BASE_ID,
                DATA_SOURCE_ID,
            )
            return {"status": "skipped", "reason": "ingestion_already_in_progress"}

        logger.error("Failed to start ingestion job [%s]: %s", code, exc, exc_info=True)
        raise
