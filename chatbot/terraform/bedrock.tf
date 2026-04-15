# ---------------------------------------------------------------------------
# Amazon Bedrock Knowledge Base
# ---------------------------------------------------------------------------

resource "aws_bedrockagent_knowledge_base" "bank_kb" {
  name        = "${local.name_prefix}-bank-kb"
  description = "Knowledge base for bank branch employee chatbot (internal documents)"
  role_arn    = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"

    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb_collection.arn
      vector_index_name = var.kb_vector_index_name

      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  depends_on = [
    aws_opensearchserverless_access_policy.kb_access,
    aws_opensearchserverless_collection.kb_collection,
    aws_iam_role_policy.bedrock_kb_opensearch_policy,
    aws_iam_role_policy.bedrock_kb_s3_policy,
    aws_iam_role_policy.bedrock_kb_model_policy,
  ]
}

# ---------------------------------------------------------------------------
# S3 Data Source — documents in this bucket are chunked and embedded
# ---------------------------------------------------------------------------

resource "aws_bedrockagent_data_source" "bank_docs" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.bank_kb.id
  name              = "${local.name_prefix}-bank-docs"
  description       = "Internal bank documents (policies, procedures, regulations)"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = aws_s3_bucket.kb_documents.arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      # FIXED_SIZE provides predictable, overlapping chunks for dense policy documents.
      # Switch to HIERARCHICAL for long documents where section context matters more.
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}
