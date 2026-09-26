output "bucket_id" {
  description = "Name of the archive bucket."
  value       = module.archive.id
}

output "bucket_arn" {
  description = "ARN of the archive bucket."
  value       = module.archive.arn
}

output "policy" {
  description = "Bucket policy: transport, encryption-header, and key guardrails."
  value       = module.archive.policy
}

output "kms_key_arn" {
  description = "Key every object is encrypted with."
  value       = module.archive.kms_key_arn
}
