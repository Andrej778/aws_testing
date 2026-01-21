# Repository File Summary

## Root Directory

### `.gitignore`
Specifies which files Git should ignore. Excludes Terraform state files, `.tfvars` files with credentials, provider cache, IDE configs, and OS-specific files to prevent sensitive data from being committed.

### `README.md`
Main documentation for the repository. Explains project structure, IAM setup, GitHub Actions deployment, and learning objectives for AWS infrastructure management with Terraform.

## `.github/workflows/`

### `terraform-deploy.yml`
GitHub Actions workflow that automatically validates, plans, and deploys Terraform infrastructure on pushes to main branch. Includes format checking, linting with tflint, security scanning with checkov, and automated PR comments with plan output.

### `terraform-destroy.yml`
GitHub Actions workflow for manually destroying infrastructure. Runs via workflow dispatch, requires environment selection, and safely tears down all resources with confirmation.

## `terraform/`

### `main.tf`
Main Terraform configuration file. Defines the Terraform backend (currently commented out), AWS provider settings, and the primary S3 bucket resource (`aws-testing-dev-bucket`) with versioning, encryption, and public access blocking.

### `backend.tf`
Defines infrastructure for Terraform remote state management. Creates S3 bucket (`aws-testing-terraform-state`) and DynamoDB table (`aws-testing-terraform-locks`) for storing state and managing locks. Both have lifecycle protection enabled.

### `variables.tf`
Declares Terraform input variables: `aws_region` (default: eu-central-1), `project_name` (default: aws-testing), and `environment` (default: dev) with validation to ensure environment is dev, staging, or prod.

### `outputs.tf`
Defines Terraform output values that are displayed after deployment. Outputs include S3 bucket names, ARNs, regions, and DynamoDB table information for both application and backend infrastructure.

### `terraform.tfvars.example`
Example configuration file showing the format for `terraform.tfvars`. Users copy this to `terraform.tfvars` and customize with their actual values. Safe to commit as it contains no real credentials.

## Excluded Files (Not in Git)

### `terraform/.terraform/`
Directory containing downloaded Terraform provider plugins (e.g., AWS provider binary). Generated during `terraform init` and excluded from version control.

### `terraform/.terraform.lock.hcl`
Terraform dependency lock file that pins provider versions. Auto-generated and excluded from version control to allow different environments to use compatible versions.

### `terraform/*.tfvars`
Actual configuration files containing potentially sensitive values like AWS region, project name, and environment settings. Excluded from Git to prevent accidental credential exposure.

### `terraform/*.tfstate`
Terraform state files containing current infrastructure state and sensitive resource information. Should never be committed; use S3 backend for remote state instead.
