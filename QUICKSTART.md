# Quick Start Guide

## ⚠️ IMPORTANT: Use Admin Credentials for This One-Time Setup

The script needs to be run with **admin AWS credentials** (not deploy-user credentials) because deploy-user doesn't have IAM permissions yet. This is a one-time setup.

See [RUN-ONCE-SETUP.md](RUN-ONCE-SETUP.md) for detailed instructions on how to temporarily use admin credentials.

## One-Command IAM Setup

**Quick method (if you have admin credentials as environment variables):**

```powershell
# Set admin credentials temporarily
$env:AWS_ACCESS_KEY_ID = "your-admin-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-admin-secret-key"
$env:AWS_REGION = "eu-central-1"

# Run the setup script
.\create-iam-policy.ps1

# Clear environment variables
Remove-Item Env:\AWS_ACCESS_KEY_ID
Remove-Item Env:\AWS_SECRET_ACCESS_KEY
Remove-Item Env:\AWS_REGION
```

**That's it!** The script will:
- ✓ Create the `TerraformDeployPolicy` with all necessary permissions
- ✓ Attach it to `deploy-user`
- ✓ Verify the setup

**Requirements:**
- AWS CLI installed ([Download here](https://aws.amazon.com/cli/))
- AWS admin credentials (IAM permissions to create policies and attach them to users)

## What This Script Does

The script creates an IAM policy that grants `deploy-user` permissions to:
- Create and manage S3 buckets (aws-testing-*)
- Create and manage DynamoDB tables (aws-testing-*)
- All necessary permissions for Terraform deployments

All permissions are scoped to resources starting with `aws-testing-*` only.

## After Running the Script

Once the IAM policy is set up, you can deploy using:

### Option 1: GitHub Actions (Automated)
Push to main branch and GitHub Actions will automatically deploy.

### Option 2: Local Deployment (Manual)
```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

## Troubleshooting

**"AWS CLI not found"**
- Install AWS CLI: https://aws.amazon.com/cli/

**"Failed to authenticate with AWS"**
- Run `aws configure` and enter your AWS credentials
- Make sure you're using credentials with IAM permissions (not deploy-user)

**"Policy already exists"**
- The script is idempotent - it will skip creation if the policy exists
- It will still verify and attach the policy if needed

**"Failed to create policy"**
- Make sure your AWS credentials have `iam:CreatePolicy` permission
- You typically need admin-level credentials to create IAM policies

## Need More Details?

See [README.md](README.md) for complete documentation.
