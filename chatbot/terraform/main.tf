terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name

  # OpenSearch Serverless collection name: lowercase, 3-32 chars, alphanumeric + hyphens
  collection_name = "${var.project_name}-kb-${var.environment}"

  # Model ARN for Claude Sonnet 4.5
  # Use cross-region inference profile if the model is not available in your region:
  #   eu.anthropic.claude-sonnet-4-5-20251001-v1:0  (EU cross-region)
  #   us.anthropic.claude-sonnet-4-5-20251001-v1:0  (US cross-region)
  model_arn = var.model_arn != "" ? var.model_arn : (
    "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-sonnet-4-5-20251001-v1:0"
  )
}
