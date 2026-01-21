# AWS Testing & Learning Repository

A learning repository for AWS deployment using Terraform.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS account with appropriate permissions

## Project Structure

```
aws_testing/
├── terraform/
│   ├── main.tf                    # Main Terraform configuration
│   ├── backend.tf                 # Remote state backend infrastructure
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output definitions
│   └── terraform.tfvars.example   # Example variables file
├── .github/
│   └── workflows/
│       ├── terraform-deploy.yml   # CI/CD deployment workflow
│       └── terraform-destroy.yml  # Manual destroy workflow
└── README.md                       # This file
```

## Getting Started

### 1. Set up IAM Permissions (First-time setup - REQUIRED)

Before deploying any infrastructure, you need to set up IAM permissions for the `deploy-user`.

Create an IAM policy named `TerraformDeployPolicy` with the following permissions and attach it to your `deploy-user`:

- **S3 Permissions**: `s3:CreateBucket`, `s3:DeleteBucket`, `s3:GetBucket*`, `s3:PutBucket*`, `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`
- **DynamoDB Permissions**: `dynamodb:CreateTable`, `dynamodb:DeleteTable`, `dynamodb:DescribeTable`, `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem`, `dynamodb:UpdateItem`, `dynamodb:TagResource`
- **Resource Scope**: All permissions scoped to `arn:aws:s3:::aws-testing-*` and `arn:aws:dynamodb:*:*:table/aws-testing-*`

### 2. Set up GitHub Secrets

Add your AWS credentials to GitHub repository secrets:
1. Go to repository Settings → Secrets and variables → Actions
2. Add `AWS_ACCESS_KEY_ID` with your deploy-user access key
3. Add `AWS_SECRET_ACCESS_KEY` with your deploy-user secret key

### 3. Deploy via GitHub Actions

Push your code to the `main` branch to trigger automatic deployment:

```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
```

The GitHub Actions workflow will automatically:
1. Initialize Terraform
2. Validate configuration
3. Run security scans (checkov, tflint)
4. Plan changes
5. Apply infrastructure changes

Monitor the deployment in the **Actions** tab of your GitHub repository.

> **Note**: The S3 backend is currently disabled. After the first successful deployment creates the backend infrastructure, you can enable it by uncommenting the backend block in `terraform/main.tf` and pushing again.

## AWS Resources

This repository includes:

### Backend Infrastructure (backend.tf)
- **S3 Bucket** (`aws-testing-terraform-state`): Stores Terraform state files
  - Versioning enabled
  - Server-side encryption (AES256)
  - Public access blocked
  - Lifecycle protection (`prevent_destroy = true`)
- **DynamoDB Table** (`aws-testing-terraform-locks`): Manages state locking
  - Pay-per-request billing
  - Lifecycle protection (`prevent_destroy = true`)

### Application Resources (main.tf)
- **S3 Bucket**: A learning resource with:
  - Versioning enabled
  - Server-side encryption (AES256)
  - Public access blocked

## Learning Notes

This repository is designed as a learning tool for:

- Terraform basics (infrastructure as code)
- AWS resource provisioning
- Remote state management with S3 backend
- State locking with DynamoDB
- Deployment automation
- Best practices for IaC

## Important Notes

- **Never commit `terraform.tfvars`** - It contains sensitive information
- All deployments are handled via GitHub Actions
- Use appropriate AWS IAM credentials with minimal required permissions
- Test in a dev environment before deploying to production
- Review the Terraform documentation: https://www.terraform.io/docs/

## GitHub Actions Workflows

### 1. Terraform Deploy Workflow

**Trigger**: Automatic on push to `main` branch or pull requests

**What it does**:
- Validates Terraform configuration
- Runs security scans (checkov, tflint)
- Creates execution plan
- Applies changes (on main push only)
- Comments plan output on pull requests

**To deploy**: Simply push to main branch

```bash
git add terraform/
git commit -m "Add new AWS resources"
git push origin main
```

### 2. Terraform Destroy Workflow

**Trigger**: Manual (via Actions tab)

**What it does**:
- Safely destroys all infrastructure
- Requires environment selection (dev/staging/prod)

**To destroy resources**:
1. Go to Actions tab in GitHub
2. Select "Terraform Destroy" workflow
3. Click "Run workflow"
4. Choose environment
5. Confirm destruction

## Resources

- [Terraform Documentation](https://www.terraform.io/docs/)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Credentials in GitHub Actions](https://github.com/aws-actions/configure-aws-credentials)
