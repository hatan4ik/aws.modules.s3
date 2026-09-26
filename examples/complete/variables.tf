variable "region" {
  description = "AWS region the bucket is created in."
  type        = string
  default     = "us-east-1"
}

variable "partition" {
  description = "AWS partition, used to build ARNs in the bucket policy."
  type        = string
  default     = "aws"
}

variable "bucket" {
  description = "Globally unique bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer managed KMS key ARN for default encryption. Uploads must name it in the x-amz-server-side-encryption-aws-kms-key-id header."
  type        = string
}

variable "log_bucket" {
  description = "Existing bucket that receives server access logs. It must use SSE-S3 and allow logging.s3.amazonaws.com to put objects under <bucket>/ (see examples/access-logging)."
  type        = string
}

variable "reader_role_arn" {
  description = "IAM role ARN allowed to list and read objects under reports/."
  type        = string
}

variable "allowed_origins" {
  description = "Origins allowed to GET and PUT objects from a browser through CORS."
  type        = set(string)
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default = {
    Environment = "production"
    Team        = "orders"
  }
}
