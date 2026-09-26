variable "region" {
  description = "AWS region the archive bucket is created in."
  type        = string
  default     = "us-east-1"
}

variable "bucket" {
  description = "Globally unique bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer managed KMS key ARN every upload must be encrypted with."
  type        = string
}

variable "retention_years" {
  description = "COMPLIANCE default retention applied to every new object version, in years."
  type        = number
  default     = 7

  validation {
    condition     = var.retention_years >= 1
    error_message = "retention_years must be at least 1."
  }
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default = {
    DataClassification = "regulated"
  }
}
