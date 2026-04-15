output "api_gateway_url" {
  description = "Base URL for the chatbot API"
  value       = "${aws_api_gateway_stage.chat_stage.invoke_url}/chat"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.chat_api.id
}

# FIX #5 — expose API key value (sensitive) so callers can retrieve it via terraform output
output "api_key_value" {
  description = "API key — pass as x-api-key header. Retrieve with: terraform output -raw api_key_value"
  value       = aws_api_gateway_api_key.chat_api_key.value
  sensitive   = true
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.bank_kb.id
}

output "data_source_id" {
  description = "Bedrock Knowledge Base Data Source ID"
  value       = aws_bedrockagent_data_source.bank_docs.data_source_id
}

output "kb_documents_bucket" {
  description = "S3 bucket — upload internal documents here; ingestion triggers automatically"
  value       = aws_s3_bucket.kb_documents.bucket
}

output "kb_documents_bucket_arn" {
  description = "S3 bucket ARN for KB documents"
  value       = aws_s3_bucket.kb_documents.arn
}

output "kb_db_cluster_endpoint" {
  description = "Aurora PostgreSQL cluster endpoint (vector store)"
  value       = aws_rds_cluster.kb_db.endpoint
}

output "conversation_log_table" {
  description = "DynamoDB table for conversation audit logs"
  value       = aws_dynamodb_table.conversation_log.name
}

output "chat_handler_lambda_name" {
  description = "Chat handler Lambda function name"
  value       = aws_lambda_function.chat_handler.function_name
}

output "log_processor_lambda_name" {
  description = "Log processor Lambda function name"
  value       = aws_lambda_function.log_processor.function_name
}

output "ingestion_trigger_lambda_name" {
  description = "Ingestion trigger Lambda — fires automatically on S3 uploads"
  value       = aws_lambda_function.ingestion_trigger.function_name
}

output "logging_queue_url" {
  description = "SQS URL for async logging queue"
  value       = aws_sqs_queue.logging_queue.url
}

output "guardrail_id" {
  description = "Bedrock Guardrail ID applied to all chat responses"
  value       = aws_bedrock_guardrail.chat_guardrail.guardrail_id
}
