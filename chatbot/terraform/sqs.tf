# ---------------------------------------------------------------------------
# SQS — Async logging pipeline
# ---------------------------------------------------------------------------

# Dead-letter queue: receives messages that the log processor fails to handle
# after maxReceiveCount attempts.
resource "aws_sqs_queue" "logging_dlq" {
  name                      = "${local.name_prefix}-logging-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Purpose = "Dead-letter queue for failed conversation log entries"
  }
}

# Main logging queue
resource "aws_sqs_queue" "logging_queue" {
  name                       = "${local.name_prefix}-logging-queue"
  visibility_timeout_seconds = 60    # Must be >= log processor Lambda timeout
  message_retention_seconds  = 86400 # 1 day (messages are short-lived — DynamoDB is the store)
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.logging_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Purpose = "Async conversation logging queue"
  }
}

# Allow the log processor Lambda to be triggered by SQS
resource "aws_lambda_event_source_mapping" "log_processor_trigger" {
  event_source_arn                   = aws_sqs_queue.logging_queue.arn
  function_name                      = aws_lambda_function.log_processor.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  enabled                            = true

  function_response_types = ["ReportBatchItemFailures"]
}
