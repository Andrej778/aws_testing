# Standalone IAM Policy Setup
# Run this file separately to create and attach the IAM policy for deploy-user
#
# Quick Start:
#   terraform init
#   terraform apply
#
# This will create the IAM policy with all required permissions and attach it to deploy-user

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # No backend - uses local state for this IAM setup
}

provider "aws" {
  region = "eu-central-1"
}

# Comprehensive IAM Policy for Terraform Deployment
resource "aws_iam_policy" "terraform_deploy" {
  name        = "TerraformDeployPolicy"
  description = "Comprehensive policy for Terraform to manage all aws-testing project resources including S3, DynamoDB, and IAM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Bucket Management - Full control over aws-testing buckets
      {
        Sid    = "S3BucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketCORS",
          "s3:PutBucketCORS",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:PutReplicationConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::aws-testing-*"
        ]
      },
      # S3 Object Management - Full control over objects in aws-testing buckets
      {
        Sid    = "S3ObjectManagement"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = [
          "arn:aws:s3:::aws-testing-*/*"
        ]
      },
      # S3 List All Buckets - Required for Terraform state backend
      {
        Sid      = "S3ListAllBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
        Resource = "*"
      },
      # DynamoDB Table Management - Full control over aws-testing tables
      {
        Sid    = "DynamoDBTableManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:DescribeLimits"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/aws-testing-*"
        ]
      },
      # DynamoDB Item Management - Full control over items in aws-testing tables
      {
        Sid    = "DynamoDBItemManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/aws-testing-*"
        ]
      },
      # DynamoDB List Tables - Required for Terraform
      {
        Sid      = "DynamoDBListTables"
        Effect   = "Allow"
        Action   = ["dynamodb:ListTables"]
        Resource = "*"
      },
      # IAM Policy Management - For managing the TerraformDeployPolicy itself
      {
        Sid    = "IAMPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = [
          "arn:aws:iam::*:policy/TerraformDeployPolicy"
        ]
      },
      # IAM User Policy Attachment - For attaching policies to deploy-user
      {
        Sid    = "IAMUserPolicyAttachment"
        Effect = "Allow"
        Action = [
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies"
        ]
        Resource = [
          "arn:aws:iam::*:user/deploy-user"
        ]
      }
    ]
  })

  tags = {
    Name        = "Terraform Deploy Policy"
    Project     = "aws-testing"
    ManagedBy   = "Terraform"
    Description = "Comprehensive policy for Terraform deployment with S3, DynamoDB, and IAM permissions"
  }
}

# Attach the policy to deploy-user
resource "aws_iam_user_policy_attachment" "deploy_user_attach" {
  user       = "deploy-user"
  policy_arn = aws_iam_policy.terraform_deploy.arn
}

# Outputs
output "policy_arn" {
  description = "ARN of the created IAM policy"
  value       = aws_iam_policy.terraform_deploy.arn
}

output "policy_name" {
  description = "Name of the created IAM policy"
  value       = aws_iam_policy.terraform_deploy.name
}

output "user_attached" {
  description = "User that the policy was attached to"
  value       = aws_iam_user_policy_attachment.deploy_user_attach.user
}

output "attach_command" {
  description = "AWS CLI command to manually attach this policy (if needed)"
  value       = "aws iam attach-user-policy --user-name deploy-user --policy-arn ${aws_iam_policy.terraform_deploy.arn}"
}

output "success_message" {
  description = "Success message with next steps"
  value       = <<-EOT
    ✓ IAM Policy Created and Attached Successfully!

    Policy ARN: ${aws_iam_policy.terraform_deploy.arn}
    Attached to: deploy-user

    The deploy-user now has permissions to:
    - Create and manage S3 buckets (aws-testing-*)
    - Create and manage DynamoDB tables (aws-testing-*)
    - Manage the TerraformDeployPolicy itself

    Next steps:
    1. Re-run your GitHub Actions workflow, or
    2. Deploy locally with: cd terraform && terraform apply
  EOT
}
