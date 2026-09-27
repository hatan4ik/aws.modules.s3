variable "region" {
  description = "AWS region both buckets are created in; access logs can only be delivered within a region."
  type        = string
  default     = "us-east-1"
}

variable "partition" {
  description = "AWS partition, used to build ARNs in the log delivery statement."
  type        = string
  default     = "aws"
}

variable "account_id" {
  description = "Account that owns both buckets; the log delivery statement is conditioned on it."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "data_bucket" {
  description = "Globally unique name of the bucket whose requests are logged."
  type        = string
}

variable "log_bucket" {
  description = "Globally unique name of the bucket that receives the access logs."
  type        = string
}

variable "log_retention_days" {
  description = "Days after which access log objects expire."
  type        = number
  default     = 400
}

variable "tags" {
  description = "Tags applied to both buckets."
  type        = map(string)
  default     = {}
}
