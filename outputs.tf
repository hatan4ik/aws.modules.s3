output "id" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "regional_domain_name" {
  description = "Regional DNS name of the S3 bucket."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
