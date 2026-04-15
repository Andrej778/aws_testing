# ---------------------------------------------------------------------------
# IAM policy for the CI/CD deploy-user to plan and apply chatbot/terraform/.
#
# IMPORTANT — must be applied with admin credentials (deploy-user lacks
# iam:CreatePolicy). Run once after any change to this file:
#
#   cd terraform/
#   AWS_PROFILE=<admin-profile> terraform apply \
#     -target=aws_iam_policy.chatbot_deploy_policy \
#     -target=aws_iam_user_policy_attachment.chatbot_deploy_policy_attachment \
#     -auto-approve
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "chatbot_deploy_policy" {
  name        = "ChatbotDeployPolicy"
  description = "Grants deploy-user the permissions needed to plan/apply chatbot/terraform/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # S3: chatbot buckets + Terraform remote state
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "arn:aws:s3:::${var.chatbot_project_name}-*",
          "arn:aws:s3:::${var.chatbot_project_name}-*/*",
          "arn:aws:s3:::aws-testing-terraform-state",
          "arn:aws:s3:::aws-testing-terraform-state/chatbot/*",
        ]
      },

      # DynamoDB: Terraform state lock + chatbot conversation log
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = ["dynamodb:*"]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/aws-testing-terraform-locks",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.chatbot_project_name}-*",
        ]
      },

      # Bedrock: Knowledge Base, Data Source, Guardrail
      {
        Sid      = "Bedrock"
        Effect   = "Allow"
        Action   = ["bedrock:*"]
        Resource = "*"
      },

      # RDS: Aurora PostgreSQL vector store + Data API for schema init
      {
        Sid      = "RDS"
        Effect   = "Allow"
        Action   = ["rds:*", "rds-data:*"]
        Resource = "*"
      },

      # Secrets Manager: Aurora DB credentials
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.chatbot_project_name}-*"
      },

      # EC2: VPC/subnet read + security group management for RDS
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateTags",
        ]
        Resource = "*"
      },

      # Lambda: chatbot functions
      {
        Sid    = "LambdaFunctions"
        Effect = "Allow"
        Action = ["lambda:*"]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.chatbot_project_name}-*"
      },
      {
        Sid    = "LambdaESM"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping", "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping", "lambda:UpdateEventSourceMapping",
          "lambda:ListEventSourceMappings",
        ]
        Resource = "*"
      },

      # API Gateway: REST API, usage plan, API key, account CW role, tags
      {
        Sid    = "APIGateway"
        Effect = "Allow"
        Action = ["apigateway:GET", "apigateway:POST", "apigateway:PUT", "apigateway:PATCH", "apigateway:DELETE"]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*",
          "arn:aws:apigateway:${var.aws_region}::/usageplans",
          "arn:aws:apigateway:${var.aws_region}::/usageplans/*",
          "arn:aws:apigateway:${var.aws_region}::/apikeys",
          "arn:aws:apigateway:${var.aws_region}::/apikeys/*",
          "arn:aws:apigateway:${var.aws_region}::/account",
          "arn:aws:apigateway:${var.aws_region}::/tags/*",
        ]
      },

      # IAM: chatbot service roles only (kept specific — most sensitive)
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:TagRole", "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy", "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::*:role/${var.chatbot_project_name}-*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/${var.chatbot_project_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["lambda.amazonaws.com", "bedrock.amazonaws.com", "apigateway.amazonaws.com"]
          }
        }
      },

      # SQS: logging queues
      {
        Sid      = "SQS"
        Effect   = "Allow"
        Action   = ["sqs:*"]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${var.chatbot_project_name}-*"
      },

      # CloudWatch Logs: Lambda and API Gateway log groups
      # :* suffix required — AWS evaluates log group ARNs with :log-stream: appended
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.chatbot_project_name}-*:*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/api-gateway/${var.chatbot_project_name}-*:*",
        ]
      },

    ]
  })
}

resource "aws_iam_user_policy_attachment" "chatbot_deploy_policy_attachment" {
  user       = var.deploy_user_name
  policy_arn = aws_iam_policy.chatbot_deploy_policy.arn
}
