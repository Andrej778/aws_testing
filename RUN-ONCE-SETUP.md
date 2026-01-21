# One-Time IAM Setup - IMPORTANT

## The Problem

Your `deploy-user` credentials are currently configured in AWS CLI, but they don't have permission to create IAM policies. This is a chicken-and-egg problem: we need IAM permissions to create IAM permissions.

## The Solution

You need to **temporarily** use admin AWS credentials to run the setup script **once**, then you can go back to using deploy-user credentials.

## Step-by-Step Instructions

### Option 1: Set Environment Variables (Recommended - Temporary)

This method doesn't change your AWS CLI configuration:

```powershell
# 1. Set your ADMIN credentials as environment variables (TEMPORARILY)
$env:AWS_ACCESS_KEY_ID = "your-admin-access-key-id"
$env:AWS_SECRET_ACCESS_KEY = "your-admin-secret-access-key"
$env:AWS_REGION = "eu-central-1"

# 2. Run the setup script
.\create-iam-policy.ps1

# 3. Clear the environment variables (go back to using deploy-user)
Remove-Item Env:\AWS_ACCESS_KEY_ID
Remove-Item Env:\AWS_SECRET_ACCESS_KEY
Remove-Item Env:\AWS_REGION
```

### Option 2: Use AWS CLI Profile (Cleaner - Recommended if you have multiple credentials)

```powershell
# 1. Create a new profile for your admin credentials
aws configure --profile admin
# Enter your admin access key, secret key, and region when prompted

# 2. Run the script with the admin profile
$env:AWS_PROFILE = "admin"
.\create-iam-policy.ps1

# 3. Switch back to default profile
Remove-Item Env:\AWS_PROFILE
```

### Option 3: Temporarily Change Default Credentials

```powershell
# 1. Backup your current credentials
Copy-Item ~/.aws/credentials ~/.aws/credentials.backup

# 2. Configure admin credentials
aws configure
# Enter your admin access key, secret key, and region

# 3. Run the setup script
.\create-iam-policy.ps1

# 4. Restore deploy-user credentials
Move-Item -Force ~/.aws/credentials.backup ~/.aws/credentials
```

## What Admin Credentials Do You Need?

The admin credentials need these IAM permissions:
- `iam:CreatePolicy`
- `iam:AttachUserPolicy`
- `iam:GetPolicy`
- `iam:ListAttachedUserPolicies`

If you're the AWS account owner, your root account credentials or IAM admin user will have these permissions.

## After Running the Script Successfully

Once the script completes successfully, you'll see:

```
========================================
SUCCESS IAM Policy Setup Complete!
========================================

Policy Name:  TerraformDeployPolicy
Policy ARN:   arn:aws:iam::881211379467:policy/TerraformDeployPolicy
Attached to:  deploy-user
```

**At this point:**
1. The `deploy-user` now has all necessary permissions
2. You can switch back to using deploy-user credentials
3. You never need to run this script again
4. GitHub Actions deployments will now work

## Verification

To verify the policy was created and attached:

```powershell
aws iam list-attached-user-policies --user-name deploy-user
```

You should see `TerraformDeployPolicy` in the output.

## Don't Have Admin Credentials?

If you don't have admin AWS credentials, you'll need to:

1. **Contact your AWS administrator** to either:
   - Run this script for you, OR
   - Manually create the policy in AWS Console (see [SETUP-IAM.md](SETUP-IAM.md))

2. **If you're learning/testing**, consider creating a new IAM user with admin permissions for this one-time setup

## Security Note

This is a **one-time setup**. After the policy is created and attached to deploy-user, you should:
- Use deploy-user credentials for all normal operations
- Store admin credentials securely
- Never commit admin credentials to git
