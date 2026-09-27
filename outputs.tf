output "id" {
  description = "Name of the bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Global domain name of the bucket (<bucket>.s3.amazonaws.com)."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket (<bucket>.s3.<region>.amazonaws.com), the value to use for CloudFront origins and DNS aliases."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID of the bucket's region, for alias records."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "region" {
  description = "Region the bucket resides in."
  value       = aws_s3_bucket.this.bucket_region
}

output "policy" {
  description = "Bucket policy document attached to the bucket (composed or policy_json_override), or null when no policy is attached."
  value       = local.policy_json
}

output "lifecycle_rule_ids" {
  description = "Ids of the declared lifecycle rules, sorted."
  value       = sort(keys(var.lifecycle_rules))
}

output "versioning" {
  description = "Versioning state applied to the bucket: Enabled, Suspended, or Disabled."
  value       = var.versioning
}

output "sse_algorithm" {
  description = "Default server-side encryption algorithm: aws:kms, AES256, or aws:kms:dsse."
  value       = var.sse_algorithm
}

output "kms_key_arn" {
  description = "Customer managed KMS key ARN used for default encryption, or null when the AWS managed key (or SSE-S3) is used."
  value       = var.kms_key_arn
}
