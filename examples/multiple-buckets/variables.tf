variable "region" {
  description = "AWS region every bucket is created in."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for every bucket name; the map key is appended (<prefix>-<key>). Include an account or team identifier so the names are globally unique."
  type        = string
}

variable "buckets" {
  description = "Buckets to create, keyed by a short dataset name. Each may pin its versioning state, a customer managed KMS key (null uses the AWS managed key), and an expiration in days for its objects."
  type = map(object({
    versioning        = optional(string, "Enabled")
    kms_key_arn       = optional(string)
    expire_after_days = optional(number)
  }))
}

variable "tags" {
  description = "Tags applied to every bucket."
  type        = map(string)
  default     = {}
}
