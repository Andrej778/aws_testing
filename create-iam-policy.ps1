# IAM Policy Creation Script
# This script creates the TerraformDeployPolicy and attaches it to deploy-user
# Run this with AWS credentials that have IAM permissions (admin credentials)

param(
    [string]$Region = "eu-central-1",
    [string]$PolicyName = "TerraformDeployPolicy",
    [string]$UserName = "deploy-user"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IAM Policy Creation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
Write-Host "Checking for AWS CLI..." -ForegroundColor Yellow
$awsCliExists = $false
try {
    $null = aws --version 2>&1
    $awsCliExists = $true
    Write-Host "OK AWS CLI found" -ForegroundColor Green
}
catch {
    Write-Host "ERROR AWS CLI not found" -ForegroundColor Red
    Write-Host "Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Get current AWS identity
Write-Host ""
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identityJson = aws sts get-caller-identity --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AWS authentication failed"
    }
    $identity = $identityJson | ConvertFrom-Json
    $accountId = $identity.Account
    Write-Host "OK Authenticated as: $($identity.Arn)" -ForegroundColor Green
    Write-Host "   Account ID: $accountId" -ForegroundColor Gray
}
catch {
    Write-Host "ERROR Failed to authenticate with AWS" -ForegroundColor Red
    Write-Host "Make sure you have AWS credentials configured" -ForegroundColor Yellow
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Create policy JSON
Write-Host ""
Write-Host "Creating policy JSON..." -ForegroundColor Yellow

$policyJson = @"
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
      "Resource": [
        "arn:aws:s3:::aws-testing-*"
      ]
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
      "Resource": [
        "arn:aws:s3:::aws-testing-*/*"
      ]
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
      "Resource": [
        "arn:aws:dynamodb:*:${accountId}:table/aws-testing-*"
      ]
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
      "Resource": [
        "arn:aws:dynamodb:*:${accountId}:table/aws-testing-*"
      ]
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
"@

# Save to temp file
$tempFile = [System.IO.Path]::GetTempFileName()
$policyJson | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
Write-Host "OK Policy JSON created" -ForegroundColor Green

# Check if policy already exists
Write-Host ""
Write-Host "Checking if policy already exists..." -ForegroundColor Yellow
$policyArn = "arn:aws:iam::${accountId}:policy/$PolicyName"
$policyExists = $false

$checkResult = aws iam get-policy --policy-arn $policyArn 2>&1
if ($LASTEXITCODE -eq 0) {
    $policyExists = $true
    Write-Host "OK Policy already exists: $policyArn" -ForegroundColor Yellow
}
else {
    Write-Host "   Policy does not exist, will create new" -ForegroundColor Gray
}

# Create policy if it doesn't exist
if (-not $policyExists) {
    Write-Host ""
    Write-Host "Creating IAM policy..." -ForegroundColor Yellow

    $createResult = aws iam create-policy --policy-name $PolicyName --description "Comprehensive policy for Terraform to manage aws-testing project resources" --policy-document "file://$tempFile" --tags "Key=Name,Value=Terraform Deploy Policy" "Key=Project,Value=aws-testing" "Key=ManagedBy,Value=PowerShell-Script" --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $result = $createResult | ConvertFrom-Json
        $policyArn = $result.Policy.Arn
        Write-Host "OK Policy created successfully!" -ForegroundColor Green
        Write-Host "   ARN: $policyArn" -ForegroundColor Gray
    }
    else {
        Write-Host "ERROR Failed to create policy" -ForegroundColor Red
        Write-Host "Error: $createResult" -ForegroundColor Red
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

# Check if policy is already attached
Write-Host ""
Write-Host "Checking if policy is attached to $UserName..." -ForegroundColor Yellow
$attachmentExists = $false

$attachedPoliciesJson = aws iam list-attached-user-policies --user-name $UserName --output json 2>&1
if ($LASTEXITCODE -eq 0) {
    $attachedPolicies = $attachedPoliciesJson | ConvertFrom-Json
    $attachmentExists = $attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq $PolicyName }

    if ($attachmentExists) {
        Write-Host "OK Policy already attached to $UserName" -ForegroundColor Yellow
    }
    else {
        Write-Host "   Policy not attached, will attach now" -ForegroundColor Gray
    }
}
else {
    Write-Host "   Could not check attachments" -ForegroundColor Gray
}

# Attach policy if not already attached
if (-not $attachmentExists) {
    Write-Host ""
    Write-Host "Attaching policy to $UserName..." -ForegroundColor Yellow

    $attachResult = aws iam attach-user-policy --user-name $UserName --policy-arn $policyArn 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Policy attached successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "ERROR Failed to attach policy" -ForegroundColor Red
        Write-Host "Error: $attachResult" -ForegroundColor Red
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

# Verify attachment
Write-Host ""
Write-Host "Verifying policy attachment..." -ForegroundColor Yellow

$verifyJson = aws iam list-attached-user-policies --user-name $UserName --output json 2>&1
if ($LASTEXITCODE -eq 0) {
    $attachedPolicies = $verifyJson | ConvertFrom-Json
    $isAttached = $attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq $PolicyName }

    if ($isAttached) {
        Write-Host "OK Verified: Policy is attached to $UserName" -ForegroundColor Green
    }
    else {
        Write-Host "WARNING Could not verify policy attachment" -ForegroundColor Yellow
    }
}
else {
    Write-Host "WARNING Could not verify policy attachment" -ForegroundColor Yellow
}

# Clean up
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUCCESS IAM Policy Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Policy Name:  $PolicyName" -ForegroundColor White
Write-Host "Policy ARN:   $policyArn" -ForegroundColor White
Write-Host "Attached to:  $UserName" -ForegroundColor White
Write-Host ""
Write-Host "Granted Permissions:" -ForegroundColor White
Write-Host "  - S3 bucket management (aws-testing-*)" -ForegroundColor Gray
Write-Host "  - S3 object operations" -ForegroundColor Gray
Write-Host "  - DynamoDB table management (aws-testing-*)" -ForegroundColor Gray
Write-Host "  - DynamoDB item operations" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Your deploy-user now has all required permissions" -ForegroundColor White
Write-Host "  2. Push changes to trigger GitHub Actions deployment" -ForegroundColor White
Write-Host "  3. Or run Terraform locally with deploy-user credentials" -ForegroundColor White
Write-Host ""
