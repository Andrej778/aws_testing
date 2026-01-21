# Missing S3 Permission

The policy you created is missing one S3 permission that Terraform needs.

## Add This Permission to Your Policy

Go to AWS Console → IAM → Policies → TerraformDeployPolicy → Edit

In the **S3BucketManagement** statement, add this action to the list:

```
"s3:GetAccelerateConfiguration"
```

The complete S3BucketManagement statement should look like this:

```json
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
    "s3:PutReplicationConfiguration",
    "s3:GetAccelerateConfiguration"
  ],
  "Resource": "arn:aws:s3:::aws-testing-*"
}
```

After updating the policy, trigger the GitHub Actions workflow again.
