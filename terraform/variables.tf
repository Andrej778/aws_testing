variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-testing"
}

variable "deploy_user_name" {
  description = "IAM user name used by CI/CD pipelines (GitHub Actions)"
  type        = string
  default     = "deploy-user"
}

variable "chatbot_project_name" {
  description = "project_name value used in chatbot/terraform — must match to scope IAM policy correctly"
  type        = string
  default     = "bank-chatbot"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
