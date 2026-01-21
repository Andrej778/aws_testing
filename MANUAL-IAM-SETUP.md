# Manual IAM Policy Setup for deploy-user

This guide shows you exactly what policy to create in the AWS Console to grant deploy-user the necessary permissions.

## Step 1: Go to AWS IAM Console

1. Open [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Policies** in the left sidebar
3. Click **Create Policy**

## Step 2: Create the Policy

1. Click the **JSON** tab
2. **Delete** the existing template
3. **Copy and paste** this entire policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketAcl",
        "s3:PutBucketAcl",
        "s3:GetBucketCORS",
        "s3:PutBucketCORS",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketLogging",
        "s3:PutBucketLogging",
        "s3:GetBucketWebsite",
        "s3:PutBucketWebsite",
        "s3:GetBucketNotification",
        "s3:PutBucketNotification",
        "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:PutReplicationConfiguration"
      ],
      "Resource": "arn:aws:s3:::aws-testing-*"
    },
    {
      "Sid": "S3ObjectManagement",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:GetObjectAcl",
        "s3:PutObjectAcl",
        "s3:GetObjectTagging",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::aws-testing-*/*"
    },
    {
      "Sid": "S3ListAllBuckets",
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBTableManagement",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:UpdateTable",
        "dynamodb:DescribeContinuousBackups",
        "dynamodb:DescribeTimeToLive",
        "dynamodb:UpdateTimeToLive",
        "dynamodb:ListTagsOfResource",
        "dynamodb:TagResource",
        "dynamodb:UntagResource",
        "dynamodb:DescribeLimits"
      ],
      "Resource": "arn:aws:dynamodb:*:881211379467:table/aws-testing-*"
    },
    {
      "Sid": "DynamoDBItemManagement",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:881211379467:table/aws-testing-*"
    },
    {
      "Sid": "DynamoDBListTables",
      "Effect": "Allow",
      "Action": [
        "dynamodb:ListTables"
      ],
      "Resource": "*"
    }
  ]
}
```

**IMPORTANT:** Replace `881211379467` with your AWS Account ID in the DynamoDB sections (lines 86 and 100).

## Step 3: Name the Policy

1. Click **Next: Tags** (tags are optional, you can skip)
2. Click **Next: Review**
3. Enter policy name: `TerraformDeployPolicy`
4. Enter description: `Permissions for deploy-user to manage aws-testing infrastructure`
5. Click **Create policy**

## Step 4: Attach Policy to deploy-user

1. In IAM Console, click **Users** in the left sidebar
2. Click on **deploy-user**
3. Click **Add permissions** → **Attach policies directly**
4. Search for `TerraformDeployPolicy`
5. Check the box next to it
6. Click **Next** → **Add permissions**

## Step 5: Verify

Run this command to verify the policy is attached:

```bash
aws iam list-attached-user-policies --user-name deploy-user
```

You should see `TerraformDeployPolicy` in the output.

## What This Policy Allows

The policy grants deploy-user permissions to:

- **S3 Buckets**: Create, delete, and manage buckets starting with `aws-testing-*`
- **S3 Objects**: Upload, download, and delete objects in those buckets
- **DynamoDB Tables**: Create, delete, and manage tables starting with `aws-testing-*`
- **DynamoDB Items**: Read and write items in those tables

All permissions are scoped to resources starting with `aws-testing-*` for security.

## Done!

Once the policy is attached, your deploy-user will have all necessary permissions to:
- Deploy infrastructure via GitHub Actions
- Run Terraform locally
- Create S3 backend and DynamoDB state locking table
