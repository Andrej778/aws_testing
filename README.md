# AWS Testing & Learning Repository

A learning repository for AWS deployment using Terraform.

> **🚀 QUICK START:** Run `.\create-iam-policy.ps1` to set up IAM permissions in one command. See [QUICKSTART.md](QUICKSTART.md) for details.

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
├── deploy.ps1                      # PowerShell deployment script (Windows)
├── Makefile                        # Build/deployment commands (Linux/Mac)
└── README.md                       # This file
```

## Getting Started

### 1. Set up IAM Permissions (First-time setup - REQUIRED)

Before deploying any infrastructure, you need to set up IAM permissions for the `deploy-user`.

#### Quick Method: PowerShell Script (Recommended - One Command!)

Run this **once** in the repository root:

```powershell
.\create-iam-policy.ps1
```

This script will:
- ✓ Create the `TerraformDeployPolicy` with all necessary permissions
- ✓ Attach it to `deploy-user`
- ✓ Verify the setup

**Requirements:** AWS CLI installed and configured with IAM permissions (admin credentials).

See [QUICKSTART.md](QUICKSTART.md) for details and troubleshooting.

#### Alternative Methods

If you can't use the PowerShell script:

**Option A: Using Terraform Locally**
```bash
cd d:\GIT_REPOSITORIES\aws_testing
terraform init
terraform apply setup-iam-policy.tf
```

**Option B: Manual Setup via AWS Console**
See [SETUP-IAM.md](SETUP-IAM.md) for detailed manual setup instructions.

#### Verify IAM Setup

After running the setup, verify the policy was attached:

```bash
aws iam list-attached-user-policies --user-name deploy-user
```

You should see `TerraformDeployPolicy` in the list.

### 2. Set up Remote State Backend (First-time setup)

This repository uses S3 for remote state storage with DynamoDB for state locking. Before using the main Terraform configuration, you need to set up the backend infrastructure.

**Step 1: Comment out the backend block temporarily**

In `terraform/main.tf`, comment out lines 11-17 (the backend "s3" block) for the initial setup:

```hcl
# backend "s3" {
#   bucket         = "aws-testing-terraform-state"
#   key            = "aws_testing/terraform.tfstate"
#   region         = "eu-central-1"
#   encrypt        = true
#   dynamodb_table = "aws-testing-terraform-locks"
# }
```

**Step 2: Create the backend infrastructure**

```bash
cd terraform
terraform init
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks
```

This creates:
- S3 bucket: `aws-testing-terraform-state` (with versioning and encryption)
- DynamoDB table: `aws-testing-terraform-locks` (for state locking)

**Step 3: Enable the backend and migrate state**

Uncomment the backend block in `terraform/main.tf`, then run:

```bash
terraform init -migrate-state
```

Type `yes` when prompted to migrate your local state to S3.

**Step 4: Verify backend setup**

```bash
aws s3 ls s3://aws-testing-terraform-state/aws_testing/
```

You should see `terraform.tfstate` in the bucket.

> **Note**: The backend resources have `prevent_destroy = true` lifecycle rules to prevent accidental deletion.

### 2. Set up your variables

Copy the example variables file and update it with your values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired AWS region, project name, and environment.

### 3. Initialize Terraform

**Windows (PowerShell):**
```powershell
.\deploy.ps1 -Command init
```

**Linux/Mac:**
```bash
make init
```

### 4. Plan your deployment

**Windows (PowerShell):**
```powershell
.\deploy.ps1 -Command plan
```

**Linux/Mac:**
```bash
make plan
```

### 5. Apply the configuration

**Windows (PowerShell):**
```powershell
.\deploy.ps1 -Command apply
```

**Linux/Mac:**
```bash
make apply
```

## Available Commands

### Windows (PowerShell)

```powershell
.\deploy.ps1 -Command init       # Initialize Terraform
.\deploy.ps1 -Command plan       # Show plan
.\deploy.ps1 -Command apply      # Apply configuration
.\deploy.ps1 -Command destroy    # Destroy resources
.\deploy.ps1 -Command fmt        # Format files
.\deploy.ps1 -Command validate   # Validate configuration
.\deploy.ps1 -Command clean      # Clean Terraform cache
```

### Linux/Mac (Make)

```bash
make init       # Initialize Terraform
make plan       # Show plan
make apply      # Apply configuration
make destroy    # Destroy resources
make fmt        # Format files
make validate   # Validate configuration
make clean      # Clean Terraform cache
```

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
- Always run `terraform plan` before `terraform apply`
- Use appropriate AWS IAM credentials with minimal required permissions
- Test in a dev environment before deploying to production
- Review the Terraform documentation: https://www.terraform.io/docs/

## CI/CD Pipeline (GitHub Actions)

This repository includes automated GitHub Actions workflows for continuous deployment.

### Setting Up GitHub Actions

1. **Add AWS Credentials to GitHub Secrets:**

   Go to your repository → Settings → Secrets and variables → Actions → New repository secret

   Add the following secrets:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

   ⚠️ **Security Best Practices:**
   - Use IAM user credentials, not root account
   - Create an IAM policy with minimal required permissions
   - Rotate credentials regularly

2. **IAM Policy Example:**

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:*",
           "terraform:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

### Workflows

#### 1. Terraform Deploy Workflow (`.github/workflows/terraform-deploy.yml`)

Automatically runs on:
- **Push to main** - Runs `terraform plan` and applies on success
- **Pull requests to main** - Runs `terraform plan` and comments results

Features:
- Terraform format validation
- Code quality checks with tflint
- Security scanning with Checkov
- Automatic comments on pull requests with plan output

#### 2. Terraform Destroy Workflow (`.github/workflows/terraform-destroy.yml`)

Manual workflow dispatch (run manually from Actions tab)
- Safely destroys resources
- Requires confirmation
- Supports multiple environments

### Example Workflow Trigger

Once set up, simply push to main:

```bash
git add terraform/
git commit -m "Add new AWS resources"
git push origin main
```

The pipeline will:
1. ✓ Format check
2. ✓ Initialize Terraform
3. ✓ Validate configuration
4. ✓ Run security scans
5. ✓ Plan changes
6. ✓ Apply changes (on main push only)

## Cleanup

To destroy all resources locally:

**Windows:**
```powershell
.\deploy.ps1 -Command destroy
.\deploy.ps1 -Command clean
```

**Linux/Mac:**
```bash
make destroy
make clean
```

Or use GitHub Actions workflow (see CI/CD Pipeline section above).

## Resources

- [Terraform Documentation](https://www.terraform.io/docs/)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Credentials in GitHub Actions](https://github.com/aws-actions/configure-aws-credentials)
