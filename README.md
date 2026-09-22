# aws.modules.s3

Versioned Terraform module for a private, customer-KMS-encrypted S3 bucket.
It applies all four public-access blocks, BucketOwnerEnforced ownership, bucket
keys, versioning, optional Object Lock at creation time, optional lifecycle
rules, and an optional caller-owned bucket policy.
