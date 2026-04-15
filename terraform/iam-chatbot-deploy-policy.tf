# ---------------------------------------------------------------------------
# IAM policy for the CI/CD deploy-user to plan and apply chatbot/terraform/.
#
# IMPORTANT — this file must be applied using admin credentials, NOT the
# deploy-user itself (which lacks iam:CreatePolicy). Run once:
#
#   cd terraform/
#   AWS_PROFILE=<admin-profile> terraform apply \
#     -target=aws_iam_policy.chatbot_deploy_policy \
#     -target=aws_iam_user_policy_attachment.chatbot_deploy_policy_attachment \
#     -auto-approve
#
# After that, the GitHub Actions chatbot-deploy.yml workflow can deploy
# the chatbot module without further manual intervention.
# ---------------------------------------------------------------------------

data "aws_iam_user" "deploy_user" {
  user_name = var.deploy_user_name
}

resource "aws_iam_policy" "chatbot_deploy_policy" {
  name        = "ChatbotDeployPolicy"
  description = "Grants deploy-user the permissions needed to plan/apply chatbot/terraform/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── S3: chatbot document bucket ──────────────────────────────────────
      {
        Sid    = "S3ChatbotBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:DeleteBucketTagging",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::${var.chatbot_project_name}-*",
          "arn:aws:s3:::${var.chatbot_project_name}-*/*",
        ]
      },

      # ── S3: Terraform remote state (read/write tfstate, lock via DynamoDB) ─
      {
        Sid    = "S3TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::aws-testing-terraform-state",
          "arn:aws:s3:::aws-testing-terraform-state/chatbot/*",
        ]
      },

      # ── DynamoDB: Terraform state locking ────────────────────────────────
      {
        Sid    = "DynamoDBTerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/aws-testing-terraform-locks"
      },

      # ── OpenSearch Serverless: vector store collection ───────────────────
      {
        Sid    = "OpenSearchServerless"
        Effect = "Allow"
        Action = [
          "aoss:CreateCollection",
          "aoss:DeleteCollection",
          "aoss:UpdateCollection",
          "aoss:DescribeCollection",
          "aoss:ListCollections",
          "aoss:BatchGetCollection",
          "aoss:CreateSecurityPolicy",
          "aoss:DeleteSecurityPolicy",
          "aoss:GetSecurityPolicy",
          "aoss:ListSecurityPolicies",
          "aoss:UpdateSecurityPolicy",
          "aoss:CreateAccessPolicy",
          "aoss:DeleteAccessPolicy",
          "aoss:GetAccessPolicy",
          "aoss:ListAccessPolicies",
          "aoss:UpdateAccessPolicy",
          "aoss:TagResource",
          "aoss:UntagResource",
          "aoss:ListTagsForResource",
        ]
        # OpenSearch Serverless does not support resource-level conditions
        # on management actions — wildcard is required here
        Resource = "*"
      },

      # ── Bedrock: Knowledge Base, Data Source, Guardrail ─────────────────
      {
        Sid    = "BedrockManagement"
        Effect = "Allow"
        Action = [
          "bedrock:CreateKnowledgeBase",
          "bedrock:DeleteKnowledgeBase",
          "bedrock:GetKnowledgeBase",
          "bedrock:UpdateKnowledgeBase",
          "bedrock:ListKnowledgeBases",
          "bedrock:TagKnowledgeBase",
          "bedrock:UntagKnowledgeBase",
          "bedrock:CreateDataSource",
          "bedrock:DeleteDataSource",
          "bedrock:GetDataSource",
          "bedrock:UpdateDataSource",
          "bedrock:ListDataSources",
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob",
          "bedrock:ListIngestionJobs",
          "bedrock:CreateGuardrail",
          "bedrock:DeleteGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:UpdateGuardrail",
          "bedrock:ListGuardrails",
          "bedrock:TagGuardrail",
          "bedrock:UntagGuardrail",
          "bedrock:CreateGuardrailVersion",
          "bedrock:DeleteGuardrailVersion",
          "bedrock:ListGuardrailVersions",
          "bedrock:ListTagsForResource",
        ]
        Resource = "*"
      },

      # ── Lambda: chatbot functions ─────────────────────────────────────────
      {
        Sid    = "LambdaChatbot"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:GetFunctionCodeSigningConfig",
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.chatbot_project_name}-*"
      },
      {
        Sid    = "LambdaEventSourceMapping"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:ListEventSourceMappings",
        ]
        # Event source mappings are account-level resources with no ARN scoping
        Resource = "*"
      },

      # ── API Gateway: REST API + account-level CW logging role ────────────
      {
        Sid    = "APIGatewayManagement"
        Effect = "Allow"
        Action = ["apigateway:GET", "apigateway:POST", "apigateway:PUT",
        "apigateway:PATCH", "apigateway:DELETE"]
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/restapis",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*",
          "arn:aws:apigateway:${var.aws_region}::/usageplans",
          "arn:aws:apigateway:${var.aws_region}::/usageplans/*",
          "arn:aws:apigateway:${var.aws_region}::/apikeys",
          "arn:aws:apigateway:${var.aws_region}::/apikeys/*",
          # Account-level CloudWatch Logs role setting
          "arn:aws:apigateway:${var.aws_region}::/account",
        ]
      },

      # ── IAM: create/manage chatbot service roles only ────────────────────
      {
        Sid    = "IAMChatbotRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::*:role/${var.chatbot_project_name}-*"
      },
      {
        # PassRole lets Terraform hand the chatbot service roles to Lambda,
        # Bedrock, and API Gateway during resource creation
        Sid      = "IAMPassRoleChatbot"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/${var.chatbot_project_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "lambda.amazonaws.com",
              "bedrock.amazonaws.com",
              "apigateway.amazonaws.com",
            ]
          }
        }
      },

      # ── DynamoDB: conversation audit log table ────────────────────────────
      {
        Sid    = "DynamoDBChatbot"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.chatbot_project_name}-*"
      },

      # ── SQS: logging queues ────────────────────────────────────────────────
      {
        Sid    = "SQSChatbot"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags",
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${var.chatbot_project_name}-*"
      },

      # ── CloudWatch Logs: Lambda and API Gateway log groups ────────────────
      {
        Sid    = "CloudWatchLogsChatbot"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource",
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.chatbot_project_name}-*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/api-gateway/${var.chatbot_project_name}-*",
        ]
      },

    ]
  })
}

resource "aws_iam_user_policy_attachment" "chatbot_deploy_policy_attachment" {
  user       = data.aws_iam_user.deploy_user.user_name
  policy_arn = aws_iam_policy.chatbot_deploy_policy.arn
}
