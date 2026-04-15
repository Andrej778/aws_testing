# ---------------------------------------------------------------------------
# S3 bucket — internal documents uploaded here are ingested into the KB
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "kb_documents" {
  bucket = "${local.name_prefix}-kb-documents"

  # FIX #11 — prevent accidental wipe of bank documents
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "kb_documents_versioning" {
  bucket = aws_s3_bucket.kb_documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_documents_encryption" {
  bucket = aws_s3_bucket.kb_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kb_documents_pab" {
  bucket = aws_s3_bucket.kb_documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "kb_documents_lifecycle" {
  bucket = aws_s3_bucket.kb_documents.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# FIX #13 — auto-ingestion: trigger a KB sync whenever a document is created or deleted
# depends_on ensures the Lambda permission exists before S3 tries to register the trigger
resource "aws_s3_bucket_notification" "kb_documents_notification" {
  bucket = aws_s3_bucket.kb_documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingestion_trigger.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_ingestion_trigger]
}
