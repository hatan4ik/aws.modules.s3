output "policy" {
  description = "The module's policy output: the document attached to the bucket, or null when none is. Known at plan only while no statement names the key."
  value       = module.bucket.policy
}
