variable "bucket" {
  description = "Name of the bucket under test."
  type        = string
  default     = "orders-data"
}

variable "deny_insecure_transport" {
  description = "Passed through to the module's deny_insecure_transport."
  type        = bool
  default     = true
}

variable "deny_unencrypted_object_uploads" {
  description = "Passed through to the module's deny_unencrypted_object_uploads."
  type        = bool
  default     = false
}

variable "deny_incorrect_encryption_key" {
  description = "Passed through to the module's deny_incorrect_encryption_key; the rendered statement then names the key ARN, which is unknown until apply."
  type        = bool
  default     = false
}
