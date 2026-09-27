output "data_bucket_id" {
  description = "Name of the logged bucket."
  value       = module.data.id
}

output "log_bucket_id" {
  description = "Name of the log destination bucket."
  value       = module.logs.id
}

output "log_bucket_policy" {
  description = "Policy of the log bucket: DenyInsecureTransport plus the log delivery grant."
  value       = module.logs.policy
}
