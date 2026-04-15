# ---------------------------------------------------------------------------
# FIX #1 — Account-level CloudWatch Logs role for API Gateway
# This is a singleton resource for the entire AWS account in this region.
# It enables access logging on all API Gateway stages that request it.
# ---------------------------------------------------------------------------

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn

  depends_on = [aws_iam_role_policy_attachment.apigw_cloudwatch_policy]
}

# ---------------------------------------------------------------------------
# REST API
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "${local.name_prefix}-chat-api"
  description = "Bank employee chatbot API — POST /chat with conversation_id + question"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# /chat resource
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "chat"
}

# POST /chat
# FIX #5 — api_key_required controlled by variable (default true)
resource "aws_api_gateway_method" "chat_post" {
  rest_api_id      = aws_api_gateway_rest_api.chat_api.id
  resource_id      = aws_api_gateway_resource.chat.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = var.enable_api_key_auth
}

resource "aws_api_gateway_integration" "chat_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.chat_api.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chat_handler.invoke_arn
}

# OPTIONS /chat — CORS preflight
resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_options_mock" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "chat_options_200" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "chat_options_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    # FIX #6 — CORS origin from variable, not hardcoded wildcard
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.chat_options_mock]
}

# Deployment
resource "aws_api_gateway_deployment" "chat_deployment" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat,
      aws_api_gateway_method.chat_post,
      aws_api_gateway_integration.chat_lambda,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.chat_lambda,
    aws_api_gateway_integration.chat_options_mock,
  ]
}

# Stage
resource "aws_api_gateway_stage" "chat_stage" {
  deployment_id = aws_api_gateway_deployment.chat_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      resourcePath       = "$context.resourcePath"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
    })
  }

  # FIX #1 — stage logging requires the account-level role to be set first
  depends_on = [aws_api_gateway_account.main]

  tags = {
    Name = "${local.name_prefix}-chat-stage"
  }
}

# FIX #16 — explicit depends_on on method settings so stage is ready first
resource "aws_api_gateway_method_settings" "chat_settings" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  stage_name  = aws_api_gateway_stage.chat_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "ERROR"
    data_trace_enabled = false
  }

  depends_on = [aws_api_gateway_stage.chat_stage]
}

# ---------------------------------------------------------------------------
# FIX #5 — API key + usage plan
# ---------------------------------------------------------------------------

resource "aws_api_gateway_api_key" "chat_api_key" {
  name        = "${local.name_prefix}-api-key"
  description = "API key for bank chatbot — distribute only to authorised branch systems"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "chat_usage_plan" {
  name        = "${local.name_prefix}-usage-plan"
  description = "Throttling and quota limits for the bank chatbot API"

  api_stages {
    api_id = aws_api_gateway_rest_api.chat_api.id
    stage  = aws_api_gateway_stage.chat_stage.stage_name
  }

  throttle_settings {
    rate_limit  = var.api_throttle_rate_limit
    burst_limit = var.api_throttle_burst_limit
  }

  quota_settings {
    limit  = var.api_quota_limit
    period = "DAY"
  }
}

resource "aws_api_gateway_usage_plan_key" "chat_api_key_binding" {
  key_id        = aws_api_gateway_api_key.chat_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.chat_usage_plan.id
}
