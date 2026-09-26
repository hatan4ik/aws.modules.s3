output "bucket_arns" {
  description = "Bucket ARNs keyed by dataset name."
  value       = { for key, bucket in module.bucket : key => bucket.arn }
}

output "bucket_ids" {
  description = "Bucket names keyed by dataset name."
  value       = { for key, bucket in module.bucket : key => bucket.id }
}

output "bucket_regional_domain_names" {
  description = "Regional domain names keyed by dataset name."
  value       = { for key, bucket in module.bucket : key => bucket.bucket_regional_domain_name }
}
