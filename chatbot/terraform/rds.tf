# ---------------------------------------------------------------------------
# Aurora PostgreSQL Serverless v2 — vector store for Bedrock Knowledge Base
#
# Bedrock Knowledge Base connects via the RDS Data API (not TCP), so:
#   - enable_http_endpoint = true is required
#   - No inbound security group rules are needed
#   - Credentials are read from Secrets Manager by both Bedrock and the
#     schema-init provisioner
# ---------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "kb_db" {
  name        = "${local.name_prefix}-kb-db-sg"
  description = "Aurora PostgreSQL cluster for Bedrock KB vector store"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "kb_db" {
  name       = "${local.name_prefix}-kb-db"
  subnet_ids = data.aws_subnets.default.ids
}

# ---------------------------------------------------------------------------
# Credentials stored in Secrets Manager
# Bedrock reads username/password from here via the Data API
# ---------------------------------------------------------------------------

resource "random_password" "kb_db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "kb_db" {
  name                    = "${local.name_prefix}-kb-db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "kb_db" {
  secret_id = aws_secretsmanager_secret.kb_db.id

  secret_string = jsonencode({
    username            = "bedrock_kb"
    password            = random_password.kb_db.result
    engine              = "aurora-postgresql"
    host                = aws_rds_cluster.kb_db.endpoint
    port                = 5432
    dbClusterIdentifier = aws_rds_cluster.kb_db.cluster_identifier
  })
}

# ---------------------------------------------------------------------------
# Aurora Serverless v2 PostgreSQL cluster
# ---------------------------------------------------------------------------

resource "aws_rds_cluster" "kb_db" {
  cluster_identifier = "${local.name_prefix}-kb-db"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "15.4"
  database_name      = "bedrock_kb"
  master_username    = "bedrock_kb"
  master_password    = random_password.kb_db.result

  # Required for Bedrock Knowledge Base — access is through the Data API
  enable_http_endpoint = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  vpc_security_group_ids  = [aws_security_group.kb_db.id]
  db_subnet_group_name    = aws_db_subnet_group.kb_db.name
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  depends_on = [aws_secretsmanager_secret_version.kb_db]
}

resource "aws_rds_cluster_instance" "kb_db" {
  identifier         = "${local.name_prefix}-kb-db-1"
  cluster_identifier = aws_rds_cluster.kb_db.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.kb_db.engine
  engine_version     = aws_rds_cluster.kb_db.engine_version
}

# ---------------------------------------------------------------------------
# Schema initialisation
# Creates the pgvector extension and the table Bedrock expects.
# Runs once via the RDS Data API using the AWS CLI on the Actions runner.
# vector(1024) matches the default output dimension of amazon.titan-embed-text-v2:0
# ---------------------------------------------------------------------------

resource "null_resource" "kb_db_schema" {
  triggers = {
    cluster_arn = aws_rds_cluster.kb_db.arn
  }

  provisioner "local-exec" {
    command = <<-EOF
      set -e
      CLUSTER_ARN="${aws_rds_cluster.kb_db.arn}"
      SECRET_ARN="${aws_secretsmanager_secret.kb_db.arn}"
      REGION="${local.region}"

      run_sql() {
        aws rds-data execute-statement \
          --resource-arn "$CLUSTER_ARN" \
          --secret-arn  "$SECRET_ARN" \
          --database    bedrock_kb \
          --region      "$REGION" \
          --sql         "$1"
      }

      echo "Waiting for Aurora cluster to accept Data API connections..."
      for i in $(seq 1 30); do
        if run_sql "SELECT 1" 2>/dev/null; then
          echo "Cluster ready."
          break
        fi
        echo "Attempt $i/30 — retrying in 15 s..."
        sleep 15
      done

      run_sql "CREATE EXTENSION IF NOT EXISTS vector;"
      run_sql "CREATE SCHEMA IF NOT EXISTS bedrock_integration;"
      run_sql "CREATE TABLE IF NOT EXISTS bedrock_integration.bedrock_kb (
                 id        uuid PRIMARY KEY,
                 embedding vector(1024),
                 chunks    text,
                 metadata  json
               );"
      run_sql "CREATE INDEX IF NOT EXISTS bedrock_kb_embed_idx
               ON bedrock_integration.bedrock_kb
               USING hnsw (embedding vector_cosine_ops);"

      echo "Schema initialisation complete."
    EOF
  }

  depends_on = [aws_rds_cluster_instance.kb_db]
}
