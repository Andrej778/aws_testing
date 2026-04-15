# ---------------------------------------------------------------------------
# DynamoDB — Conversation audit log
# Partition key: conversation_id  |  Sort key: timestamp (ISO-8601 UTC)
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "conversation_log" {
  name         = "${local.name_prefix}-conversation-log"
  billing_mode = "PAY_PER_REQUEST"

  # FIX #11 — prevent accidental deletion of the compliance audit log
  lifecycle {
    prevent_destroy = true
  }
  hash_key  = "conversation_id"
  range_key = "timestamp"

  attribute {
    name = "conversation_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # TTL — automatically expire old entries to control storage costs
  ttl {
    attribute_name = "expires_at"
    enabled        = var.conversation_log_ttl_days > 0
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Purpose = "Immutable audit log for bank employee chatbot conversations"
  }
}
