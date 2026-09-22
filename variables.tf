variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for default bucket encryption."
  type        = string
}

variable "force_destroy" {
  description = "Whether non-empty bucket deletion is permitted. Keep false for production data."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Whether S3 versioning is enabled."
  type        = bool
  default     = true
}

variable "object_lock" {
  description = "Optional object-lock configuration. Object Lock can only be enabled when a bucket is first created."
  type = object({
    enabled        = bool
    retention_mode = optional(string)
    retention_days = optional(number)
  })
  default = {
    enabled = false
  }
}

variable "bucket_policy_json" {
  description = "Optional complete bucket-policy JSON."
  type        = string
  default     = null
  nullable    = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules keyed by stable logical name."
  type = map(object({
    noncurrent_version_expiration_days = optional(number)
    abort_incomplete_multipart_days    = optional(number)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to the S3 bucket."
  type        = map(string)
  default     = {}
}
