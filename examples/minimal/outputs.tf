output "bucket_id" {
  description = "Name of the bucket."
  value       = module.bucket.id
}

output "bucket_arn" {
  description = "ARN of the bucket."
  value       = module.bucket.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket."
  value       = module.bucket.bucket_regional_domain_name
}

output "policy" {
  description = "Bucket policy the module attached: the DenyInsecureTransport statement only."
  value       = module.bucket.policy
}
