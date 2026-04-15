variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

# FIX #3: Tightened max from 21 to 17 chars.
# The OpenSearch Serverless collection name is "${project_name}-kb-${environment}",
# which must be ≤ 32 chars. Worst case: 17 + "-kb-" (4) + "staging" (7) = 28 ≤ 32.
variable "project_name" {
  description = "Project name — prefix for all resource names. Lowercase, hyphens only, max 17 chars."
  type        = string
  default     = "bank-chatbot"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,16}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens, starting with a letter, 2-17 chars total."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "model_arn" {
  description = <<-EOT
    Full ARN for the Claude LLM used in retrieve_and_generate.
    Leave empty to use the default foundation model ARN for Claude Sonnet 4.5.
    Use a cross-region inference profile ARN if the model is not available in your region.
    Example (EU cross-region):
      arn:aws:bedrock:eu-central-1:ACCOUNT_ID:inference-profile/eu.anthropic.claude-sonnet-4-5-20251001-v1:0
  EOT
  type        = string
  default     = ""
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID for the Knowledge Base"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "kb_vector_index_name" {
  description = "OpenSearch index name for vector embeddings"
  type        = string
  default     = "bank-kb-index"
}

variable "kb_number_of_results" {
  description = "Number of KB results to retrieve per query"
  type        = number
  default     = 5
}

variable "lambda_memory_mb" {
  description = "Memory (MB) allocated to the chat handler Lambda"
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Timeout (seconds) for the chat handler Lambda"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "conversation_log_ttl_days" {
  description = "DynamoDB TTL for conversation log items (days). Set to 0 to disable."
  type        = number
  default     = 365
}

# FIX #5 — API authentication
variable "enable_api_key_auth" {
  description = <<-EOT
    Require an x-api-key header on every POST /chat request.
    Set to false only for local testing. MUST be true for any non-dev environment.
    For production, replace with Cognito or IAM authorizer.
  EOT
  type        = bool
  default     = true
}

variable "api_throttle_rate_limit" {
  description = "Steady-state API Gateway request rate (requests/second)"
  type        = number
  default     = 5
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst capacity (requests)"
  type        = number
  default     = 10
}

variable "api_quota_limit" {
  description = "Maximum API calls per day per usage plan"
  type        = number
  default     = 1000
}

# FIX #6 — CORS
variable "cors_allowed_origin" {
  description = <<-EOT
    Origin returned in Access-Control-Allow-Origin.
    Set to your frontend URL in production (e.g. https://intranet.example-bank.com).
    Wildcard '*' is only acceptable for dev.
  EOT
  type        = string
  default     = "*"
}

# FIX #12 — input length guard
variable "question_max_length" {
  description = "Maximum allowed length of the question field (characters). Prevents runaway LLM costs."
  type        = number
  default     = 2000
}
