variable "region" {
  description = "AWS region the bucket is created in."
  type        = string
  default     = "us-east-1"
}

variable "bucket" {
  description = "Globally unique bucket name (3-63 lowercase letters, digits, dots, or hyphens)."
  type        = string
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
