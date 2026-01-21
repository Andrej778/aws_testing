output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.learning_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.learning_bucket.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.learning_bucket.region
}

output "backend_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB state lock table"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB state lock table"
  value       = aws_dynamodb_table.terraform_locks.arn
}
