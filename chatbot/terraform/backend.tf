# Remote state backend — uses the same S3 bucket and DynamoDB lock table
# created by the root terraform/ bootstrap module.
# The chatbot state is stored under a separate key so it never conflicts
# with the root module state.
#
# Prerequisites (already deployed by root terraform/):
#   S3 bucket  : aws-testing-terraform-state
#   DynamoDB   : aws-testing-terraform-locks

terraform {
  backend "s3" {
    bucket         = "aws-testing-terraform-state"
    key            = "chatbot/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "aws-testing-terraform-locks"
  }
}
