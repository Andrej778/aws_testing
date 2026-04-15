# ---------------------------------------------------------------------------
# CloudWatch Log Groups — created explicitly for retention control
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "chat_handler_logs" {
  name              = "/aws/lambda/${local.name_prefix}-chat-handler"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "log_processor_logs" {
  name              = "/aws/lambda/${local.name_prefix}-log-processor"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/api-gateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

# FIX #13 — log group for auto-ingestion trigger Lambda
resource "aws_cloudwatch_log_group" "ingestion_trigger_logs" {
  name              = "/aws/lambda/${local.name_prefix}-ingestion-trigger"
  retention_in_days = var.log_retention_days
}
