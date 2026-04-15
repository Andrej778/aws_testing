# ---------------------------------------------------------------------------
# Amazon OpenSearch Serverless — vector store for the Bedrock Knowledge Base
# ---------------------------------------------------------------------------

# Encryption policy (required before collection can be created)
resource "aws_opensearchserverless_security_policy" "kb_encryption" {
  name        = "${local.name_prefix}-kb-enc"
  type        = "encryption"
  description = "Encryption policy for ${local.name_prefix} KB collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

# Network policy — public access is required for Amazon Bedrock to reach the collection.
# Security is enforced at the data access policy level (IAM principal + permission scoping).
resource "aws_opensearchserverless_security_policy" "kb_network" {
  name        = "${local.name_prefix}-kb-net"
  type        = "network"
  description = "Network policy for ${local.name_prefix} KB collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# Data access policy — grants Bedrock KB role full index read/write on the collection.
# Bedrock needs CreateIndex on first deploy so it can provision the vector index.
resource "aws_opensearchserverless_access_policy" "kb_access" {
  name        = "${local.name_prefix}-kb-access"
  type        = "data"
  description = "Data access for Bedrock KB role on ${local.name_prefix} collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${local.collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems",
          ]
        }
      ]
      Principal = [aws_iam_role.bedrock_kb_role.arn]
    }
  ])
}

# OpenSearch Serverless collection (VECTORSEARCH type)
resource "aws_opensearchserverless_collection" "kb_collection" {
  name        = local.collection_name
  type        = "VECTORSEARCH"
  description = "Vector search collection for ${local.name_prefix} bank chatbot"

  depends_on = [
    aws_opensearchserverless_security_policy.kb_encryption,
    aws_opensearchserverless_security_policy.kb_network,
  ]
}
