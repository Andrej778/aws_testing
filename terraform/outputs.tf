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
