output "bucket_name" {
  description = "Unique name for the bucket under test."
  value       = local.bucket_name
}

output "tags" {
  description = "Identifying tags for the bucket under test."
  value       = local.tags
}
