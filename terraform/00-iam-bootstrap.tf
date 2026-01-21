# IAM Bootstrap Policy
# This file MUST be applied first, before any other resources
# It grants the deploy-user the necessary permissions to create S3 buckets and DynamoDB tables
#
# The filename starts with "00-" to ensure it's processed first alphabetically

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Comprehensive IAM Policy for Terraform Deployment
resource "aws_iam_policy" "terraform_deploy" {
  name        = "TerraformDeployPolicy"
  description = "Comprehensive policy for Terraform to manage all aws-testing project resources"

  # Allow the policy to be updated/replaced
  lifecycle {
    create_before_destroy = true
  }

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
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/aws-testing-*"
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
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/aws-testing-*"
        ]
      },
      # DynamoDB List Tables - Required for Terraform
      {
        Sid      = "DynamoDBListTables"
        Effect   = "Allow"
        Action   = ["dynamodb:ListTables"]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "Terraform Deploy Policy"
    Project     = "aws-testing"
    ManagedBy   = "Terraform"
    Description = "Grants permissions for Terraform to manage aws-testing resources"
  }
}

# Attach the policy to deploy-user
# Note: This requires the user running Terraform to have IAM permissions
resource "aws_iam_user_policy_attachment" "deploy_user_attach" {
  user       = "deploy-user"
  policy_arn = aws_iam_policy.terraform_deploy.arn

  # If this fails, the policy was created but not attached
  # You can attach it manually via AWS Console or CLI
}

# Outputs
output "iam_policy_arn" {
  description = "ARN of the Terraform deployment IAM policy"
  value       = aws_iam_policy.terraform_deploy.arn
}

output "iam_policy_attached_to" {
  description = "IAM user that has the policy attached"
  value       = "deploy-user"
}
