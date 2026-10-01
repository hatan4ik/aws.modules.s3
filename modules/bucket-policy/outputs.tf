output "json" {
  description = "Rendered bucket policy document, sorted by Sid, or null when no guardrail is enabled and no statement is declared."
  value       = local.json

  precondition {
    condition     = !var.deny_incorrect_encryption_key || var.kms_key_arn != null
    error_message = "deny_incorrect_encryption_key requires kms_key_arn: the guardrail denies uploads whose KMS key header differs from that key."
  }

  precondition {
    condition     = alltrue([for resource in local.declared_resources : resource == var.bucket_arn || startswith(resource, "${var.bucket_arn}/")])
    error_message = "Every statements[*].resources entry must be bucket_arn or an object path under it (<bucket_arn>/...); a bucket policy cannot reference another bucket."
  }

  # S3 limits a bucket policy to 20 KB. The rendered document is minified JSON,
  # so its length is the size S3 evaluates.
  precondition {
    condition     = length(local.json == null ? "" : local.json) <= 20480
    error_message = "The rendered bucket policy is ${length(local.json == null ? "" : local.json)} characters; S3 limits a bucket policy to 20 KB (20480 bytes). Merge statements, share conditions, or use wildcards in resources to shrink it."
  }
}

output "statement_count" {
  description = "Number of statements in the rendered document, including enabled guardrails."
  value       = length(local.statements)
}
