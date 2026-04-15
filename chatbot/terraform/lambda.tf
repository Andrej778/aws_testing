# ---------------------------------------------------------------------------
# Lambda packaging
# ---------------------------------------------------------------------------

data "archive_file" "chat_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/chat_handler"
  output_path = "${path.module}/../lambda/chat_handler.zip"
}

data "archive_file" "log_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/log_processor"
  output_path = "${path.module}/../lambda/log_processor.zip"
}

data "archive_file" "ingestion_trigger_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ingestion_trigger"
  output_path = "${path.module}/../lambda/ingestion_trigger.zip"
}

# ---------------------------------------------------------------------------
# Chat Handler Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "chat_handler" {
  function_name = "${local.name_prefix}-chat-handler"
  description   = "Processes chat requests: adds system prompt, calls Bedrock KB, returns answer"

  filename         = data.archive_file.chat_handler_zip.output_path
  source_code_hash = data.archive_file.chat_handler_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"

  role        = aws_iam_role.chat_handler_role.arn
  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.bank_kb.id
      MODEL_ARN         = local.model_arn
      SQS_QUEUE_URL     = aws_sqs_queue.logging_queue.url
      KB_NUM_RESULTS    = tostring(var.kb_number_of_results)
      # FIX #6 — CORS origin from variable
      CORS_ALLOWED_ORIGIN = var.cors_allowed_origin
      # FIX #12 — input length guard
      QUESTION_MAX_LENGTH = tostring(var.question_max_length)
      # FIX #7 — Bedrock Guardrail
      GUARDRAIL_ID      = aws_bedrock_guardrail.chat_guardrail.guardrail_id
      GUARDRAIL_VERSION = "DRAFT"
      LOG_LEVEL         = "INFO"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.chat_handler_logs,
    aws_iam_role_policy_attachment.chat_handler_basic_exec,
  ]
}

resource "aws_lambda_permission" "apigw_invoke_chat_handler" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Log Processor Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "log_processor" {
  function_name = "${local.name_prefix}-log-processor"
  description   = "Reads conversation log entries from SQS and persists them to DynamoDB"

  filename         = data.archive_file.log_processor_zip.output_path
  source_code_hash = data.archive_file.log_processor_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"

  role        = aws_iam_role.log_processor_role.arn
  memory_size = 256
  timeout     = 30

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.conversation_log.name
      LOG_TTL_DAYS        = tostring(var.conversation_log_ttl_days)
      LOG_LEVEL           = "INFO"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.log_processor_logs,
    aws_iam_role_policy_attachment.log_processor_basic_exec,
  ]
}

# ---------------------------------------------------------------------------
# FIX #13 — Ingestion Trigger Lambda: auto-syncs KB on S3 uploads/deletes
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "ingestion_trigger" {
  function_name = "${local.name_prefix}-ingestion-trigger"
  description   = "Starts a Bedrock KB ingestion job when documents are added or removed from S3"

  filename         = data.archive_file.ingestion_trigger_zip.output_path
  source_code_hash = data.archive_file.ingestion_trigger_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.12"

  role        = aws_iam_role.ingestion_trigger_role.arn
  memory_size = 128
  timeout     = 30

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.bank_kb.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.bank_docs.data_source_id
      LOG_LEVEL         = "INFO"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ingestion_trigger_logs,
    aws_iam_role_policy_attachment.ingestion_trigger_basic_exec,
  ]
}

# Allow S3 to invoke the ingestion trigger Lambda
resource "aws_lambda_permission" "s3_invoke_ingestion_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.kb_documents.arn
}
