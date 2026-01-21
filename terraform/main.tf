terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Temporarily commented out - will be enabled after backend infrastructure is created
  # backend "s3" {
  #   bucket         = "aws-testing-terraform-state"
  #   key            = "aws_testing/terraform.tfstate"
  #   region         = "eu-central-1"
  #   encrypt        = true
  #   dynamodb_table = "aws-testing-terraform-locks"
  # }
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

# Example: S3 bucket for learning
resource "aws_s3_bucket" "learning_bucket" {
  bucket = "${var.project_name}-${var.environment}-bucket"
}

resource "aws_s3_bucket_versioning" "learning_bucket_versioning" {
  bucket = aws_s3_bucket.learning_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "learning_bucket_encryption" {
  bucket = aws_s3_bucket.learning_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "learning_bucket_pab" {
  bucket = aws_s3_bucket.learning_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
