output "bucket_id" {
  description = "Name of the bucket."
  value       = module.bucket.id
}

output "bucket_arn" {
  description = "ARN of the bucket."
  value       = module.bucket.arn
}

output "bucket_domain_name" {
  description = "Global domain name of the bucket."
  value       = module.bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket."
  value       = module.bucket.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID for alias records to the bucket."
  value       = module.bucket.hosted_zone_id
}

output "region" {
  description = "Region the bucket resides in."
  value       = module.bucket.region
}

output "policy" {
  description = "Composed bucket policy: the three guardrails plus the reader statements."
  value       = module.bucket.policy
}

output "lifecycle_rule_ids" {
  description = "Ids of the lifecycle rules, sorted."
  value       = module.bucket.lifecycle_rule_ids
}

output "versioning" {
  description = "Versioning state."
  value       = module.bucket.versioning
}

output "sse_algorithm" {
  description = "Default encryption algorithm."
  value       = module.bucket.sse_algorithm
}

output "kms_key_arn" {
  description = "Customer managed key used for default encryption."
  value       = module.bucket.kms_key_arn
}
