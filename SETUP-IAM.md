# IAM Policy Setup for Terraform Deployment

This guide helps you set up the necessary IAM permissions for the `deploy-user` to deploy AWS infrastructure via Terraform.

## Problem

The `deploy-user` needs specific permissions to create and manage:
- S3 buckets (for application and Terraform state)
- DynamoDB tables (for Terraform state locking)

## Solution

Use Terraform to create and attach the required IAM policy.

## Prerequisites

You need AWS credentials with IAM permissions to:
- Create IAM policies (`iam:CreatePolicy`)
- Attach policies to users (`iam:AttachUserPolicy`)

These are typically admin-level permissions. Use your personal AWS credentials (not the deploy-user credentials).

## Steps

### Option 1: Apply with Terraform (Recommended)

1. **Configure AWS credentials** with admin/IAM permissions:
   ```bash
   # Set your admin AWS credentials
   export AWS_ACCESS_KEY_ID="your-admin-access-key"
   export AWS_SECRET_ACCESS_KEY="your-admin-secret-key"
   export AWS_REGION="eu-central-1"
   ```

2. **Initialize Terraform** in the project root:
   ```bash
   cd d:\GIT_REPOSITORIES\aws_testing
   terraform init
   ```

3. **Apply the IAM policy configuration**:
   ```bash
   terraform apply -target=aws_iam_policy.terraform_deploy -target=aws_iam_user_policy_attachment.deploy_user_attach -auto-approve
   ```

   Or use the standalone file:
   ```bash
   terraform apply -auto-approve setup-iam-policy.tf
   ```

4. **Verify the policy was created**:
   ```bash
   aws iam list-attached-user-policies --user-name deploy-user
   ```

### Option 2: Apply via AWS Console

1. Open the [IAM Console](https://console.aws.amazon.com/iam/)
2. Navigate to **Policies** → **Create Policy**
3. Switch to the **JSON** tab
4. Copy the policy from `terraform/iam-policy.tf` (the `policy` field in the `aws_iam_policy` resource)
5. Name it: `TerraformDeployPolicy`
6. Create the policy
7. Go to **Users** → `deploy-user` → **Permissions** → **Add permissions**
8. Attach the `TerraformDeployPolicy`

### Option 3: Apply via AWS CLI

If you've already created the policy using Terraform, get the ARN from the output:

```bash
# Get the policy ARN (from Terraform output)
POLICY_ARN=$(terraform output -raw terraform_deploy_policy_arn)

# Attach to deploy-user
aws iam attach-user-policy \
  --user-name deploy-user \
  --policy-arn $POLICY_ARN
```

Or create it directly with AWS CLI:

```bash
# Create the policy
aws iam create-policy \
  --policy-name TerraformDeployPolicy \
  --policy-document file://C:/Users/Andrej/AppData/Local/Temp/claude/d--GIT-REPOSITORIES/fc4c469c-abc1-4828-a01c-b0993c18f29b/scratchpad/terraform-deploy-policy.json

# Attach to user (replace ACCOUNT_ID with your AWS account ID)
aws iam attach-user-policy \
  --user-name deploy-user \
  --policy-arn arn:aws:iam::881211379467:policy/TerraformDeployPolicy
```

## Permissions Granted

The policy grants the following permissions (all scoped to `aws-testing-*` resources):

### S3 Permissions
- Create, delete, and manage S3 buckets
- Configure versioning, encryption, and public access blocking
- Read, write, and delete objects

### DynamoDB Permissions
- Create, delete, and manage DynamoDB tables
- Read, write, update, and delete items
- Manage table tags and settings

### General Permissions
- List all S3 buckets (required for Terraform)

## Security Notes

- All permissions are scoped to resources starting with `aws-testing-*`
- This follows the principle of least privilege
- The policy does NOT grant access to other AWS resources
- Safe for learning and testing environments

## After Setup

Once the policy is attached:

1. **Re-run your GitHub Actions workflow** or
2. **Deploy locally** with the deploy-user credentials

The deployment should now succeed!

## Verify Permissions

Test that the deploy-user can now create S3 buckets:

```bash
# Switch to deploy-user credentials
export AWS_ACCESS_KEY_ID="deploy-user-access-key"
export AWS_SECRET_ACCESS_KEY="deploy-user-secret-key"

# Test S3 bucket creation
aws s3api create-bucket \
  --bucket aws-testing-test-permissions \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Clean up test bucket
aws s3 rb s3://aws-testing-test-permissions
```

## Troubleshooting

**Error: "User: ... is not authorized to perform: iam:CreatePolicy"**
- You need to use AWS credentials with IAM permissions
- Switch to an admin account or request permission from your AWS administrator

**Error: "Entity already exists"**
- The policy already exists - skip to attaching it to the user
- Or delete the existing policy first: `aws iam delete-policy --policy-arn <arn>`

## Files

- `setup-iam-policy.tf` - Standalone Terraform file to create and attach the policy
- `terraform/iam-policy.tf` - IAM policy definition (part of main infrastructure)
- `SETUP-IAM.md` - This guide

## Next Steps

After successfully setting up IAM permissions, return to the main deployment:
- See [README.md](README.md) for deployment instructions
- The GitHub Actions workflow should now run successfully
