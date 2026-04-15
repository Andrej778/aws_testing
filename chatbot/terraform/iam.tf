# ---------------------------------------------------------------------------
# IAM — Bedrock Knowledge Base role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bedrock_kb_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "bedrock_kb_role" {
  name               = "${local.name_prefix}-bedrock-kb-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_kb_trust.json
  description        = "Allows Bedrock Knowledge Base to access S3, OpenSearch, and embedding model"
}

resource "aws_iam_role_policy" "bedrock_kb_s3_policy" {
  name = "s3-documents-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.kb_documents.arn, "${aws_s3_bucket.kb_documents.arn}/*"]
        Condition = {
          StringEquals = { "aws:ResourceAccount" = local.account_id }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_opensearch_policy" {
  name = "opensearch-serverless-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = aws_opensearchserverless_collection.kb_collection.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_model_policy" {
  name = "bedrock-embedding-model-access"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# IAM — Shared Lambda trust policy
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# IAM — Chat Handler Lambda execution role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "chat_handler_role" {
  name               = "${local.name_prefix}-chat-handler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  description        = "Execution role for the chat handler Lambda"
}

resource "aws_iam_role_policy_attachment" "chat_handler_basic_exec" {
  role       = aws_iam_role.chat_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "chat_handler_bedrock_policy" {
  name = "bedrock-retrieve-and-generate"
  role = aws_iam_role.chat_handler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:RetrieveAndGenerate", "bedrock:Retrieve"]
        Resource = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/*"
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-sonnet-4-5*",
          "arn:aws:bedrock:${local.region}:${local.account_id}:inference-profile/*",
        ]
      },
      # FIX #7 — allow chat handler to apply the guardrail
      {
        Effect   = "Allow"
        Action   = ["bedrock:ApplyGuardrail"]
        Resource = aws_bedrock_guardrail.chat_guardrail.guardrail_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "chat_handler_sqs_policy" {
  name = "sqs-send-log"
  role = aws_iam_role.chat_handler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.logging_queue.arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# IAM — Log Processor Lambda execution role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "log_processor_role" {
  name               = "${local.name_prefix}-log-processor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  description        = "Execution role for the async log processor Lambda"
}

resource "aws_iam_role_policy_attachment" "log_processor_basic_exec" {
  role       = aws_iam_role.log_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "log_processor_sqs_policy" {
  name = "sqs-consume-log"
  role = aws_iam_role.log_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [aws_sqs_queue.logging_queue.arn, aws_sqs_queue.logging_dlq.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "log_processor_dynamodb_policy" {
  name = "dynamodb-put-conversation-log"
  role = aws_iam_role.log_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.conversation_log.arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# FIX #13 — IAM: Ingestion Trigger Lambda execution role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ingestion_trigger_role" {
  name               = "${local.name_prefix}-ingestion-trigger-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  description        = "Execution role for the S3-triggered KB ingestion Lambda"
}

resource "aws_iam_role_policy_attachment" "ingestion_trigger_basic_exec" {
  role       = aws_iam_role.ingestion_trigger_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ingestion_trigger_bedrock_policy" {
  name = "bedrock-start-ingestion"
  role = aws_iam_role.ingestion_trigger_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob"]
        Resource = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${aws_bedrockagent_knowledge_base.bank_kb.id}"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# FIX #1 — API Gateway CloudWatch Logs account-level role
# NOTE: aws_api_gateway_account is a singleton per region per AWS account.
# If another stack in this account already manages it, import it first:
#   terraform import aws_api_gateway_account.main <account-id>
# ---------------------------------------------------------------------------

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name               = "${local.name_prefix}-apigw-cw-role"
  assume_role_policy = data.aws_iam_policy_document.apigw_trust.json
  description        = "Allows API Gateway to push access logs to CloudWatch Logs"
}

data "aws_iam_policy_document" "apigw_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_policy" {
  role       = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
