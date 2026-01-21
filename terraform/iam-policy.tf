# IAM Policy for Terraform Deployment User
# This file creates the IAM policy needed for the deploy-user to manage AWS resources
# Apply this separately if your IAM user lacks permissions

# IAM Policy for Terraform deployments
resource "aws_iam_policy" "terraform_deploy" {
  name        = "TerraformDeployPolicy"
  description = "Policy for Terraform to manage S3 buckets and DynamoDB tables for aws-testing project"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging"
        ]
        Resource = [
          "arn:aws:s3:::aws-testing-*"
        ]
      },
      {
        Sid    = "S3ObjectManagement"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-testing-*/*"
        ]
      },
      {
        Sid    = "DynamoDBManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:UpdateTable",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/aws-testing-*"
      },
      {
        Sid      = "TerraformStateManagement"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
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

# Attach policy to the deploy-user
# NOTE: This resource is commented out by default
# Uncomment and apply separately if you need to attach the policy via Terraform
# Make sure you have permissions to modify IAM before uncommenting this

# resource "aws_iam_user_policy_attachment" "deploy_user_attach" {
#   user       = "deploy-user"
#   policy_arn = aws_iam_policy.terraform_deploy.arn
# }

# Output the policy ARN for manual attachment
output "terraform_deploy_policy_arn" {
  description = "ARN of the Terraform deployment policy - use this to attach to your IAM user manually"
  value       = aws_iam_policy.terraform_deploy.arn
}

output "attach_policy_command" {
  description = "AWS CLI command to attach this policy to deploy-user"
  value       = "aws iam attach-user-policy --user-name deploy-user --policy-arn ${aws_iam_policy.terraform_deploy.arn}"
}
