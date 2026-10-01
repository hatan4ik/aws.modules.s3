variable "bucket_arn" {
  description = "ARN of the bucket the policy applies to (arn:<partition>:s3:::<name>). Statement resources default to this ARN and its objects, and every declared resource must lie within it."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[a-z][a-z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_arn))
    error_message = "bucket_arn must be an S3 bucket ARN of the form arn:<partition>:s3:::<bucket-name>."
  }
}

variable "statements" {
  description = "Policy statements keyed by alphanumeric Sid. Each names its principals by type (AWS, Service, Federated, CanonicalUser) or sets principal_all for the wildcard principal, lists actions, optionally restricts resources (default: the bucket and its objects), and may add conditions that are grouped by test. The guardrail Sids DenyInsecureTransport, DenyUnencryptedObjectUploads, and DenyIncorrectEncryptionKey are reserved."
  type = map(object({
    effect        = optional(string, "Allow")
    principals    = optional(map(set(string)), {})
    principal_all = optional(bool, false)
    actions       = set(string)
    resources     = optional(set(string))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = set(string)
    })), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for sid in keys(var.statements) : can(regex("^[A-Za-z0-9]+$", sid))])
    error_message = "Every statements key is a Sid and must contain only letters and digits."
  }

  validation {
    condition     = length(setintersection(toset(keys(var.statements)), toset(["DenyInsecureTransport", "DenyUnencryptedObjectUploads", "DenyIncorrectEncryptionKey"]))) == 0
    error_message = "The Sids DenyInsecureTransport, DenyUnencryptedObjectUploads, and DenyIncorrectEncryptionKey are reserved for the guardrail statements; enable them with their flags instead."
  }

  validation {
    condition     = alltrue([for statement in values(var.statements) : contains(["Allow", "Deny"], statement.effect)])
    error_message = "statements[*].effect must be Allow or Deny."
  }

  validation {
    condition     = alltrue([for statement in values(var.statements) : length(statement.actions) > 0])
    error_message = "statements[*].actions must list at least one action."
  }

  validation {
    condition     = alltrue([for statement in values(var.statements) : statement.principal_all != (length(statement.principals) > 0)])
    error_message = "Each statement must name principals by type or set principal_all = true, and not both."
  }

  validation {
    condition = alltrue(flatten([for statement in values(var.statements) : [
      for type, identifiers in statement.principals : contains(["AWS", "Service", "Federated", "CanonicalUser"], type) && length(identifiers) > 0
    ]]))
    error_message = "statements[*].principals keys must be AWS, Service, Federated, or CanonicalUser, each with at least one identifier."
  }

  validation {
    condition     = alltrue([for statement in values(var.statements) : statement.resources == null ? true : length(statement.resources) > 0])
    error_message = "statements[*].resources must list at least one resource when set; omit it to target the bucket and its objects."
  }

  validation {
    condition = alltrue(flatten([for statement in values(var.statements) : [
      for condition in statement.conditions : length(condition.test) > 0 && length(condition.variable) > 0 && length(condition.values) > 0
    ]]))
    error_message = "statements[*].conditions entries need a non-empty test, variable, and at least one value."
  }

  # Conditions are rendered as a map keyed by test, then by variable, so a
  # repeated pair would otherwise surface as Terraform's own duplicate-key error.
  validation {
    condition     = alltrue([for statement in values(var.statements) : length(distinct([for condition in statement.conditions : "${condition.test}:${condition.variable}"])) == length(statement.conditions)])
    error_message = "statements[*].conditions must not repeat the same test and variable within one statement; list every value in a single condition instead."
  }

  # The root module keeps all four public access blocks on, and S3 rejects a
  # policy that grants public access while block_public_policy is set. An
  # unconditioned wildcard Allow is always public, so it is rejected here rather
  # than at apply.
  validation {
    condition = alltrue([for statement in values(var.statements) :
      statement.effect != "Allow" || length(statement.conditions) > 0 || !(statement.principal_all || anytrue([for identifiers in values(statement.principals) : contains(identifiers, "*")]))
    ])
    error_message = "An Allow statement with a wildcard principal (principal_all = true, or \"*\" as an identifier) must carry at least one condition; an unconditioned wildcard Allow is a public policy, which the public access block rejects."
  }
}

variable "deny_insecure_transport" {
  description = "Add the DenyInsecureTransport statement: deny every S3 action on the bucket and its objects when the request does not use TLS (aws:SecureTransport is false)."
  type        = bool
  default     = true
  nullable    = false
}

variable "deny_unencrypted_object_uploads" {
  description = "Add the DenyUnencryptedObjectUploads statement: deny s3:PutObject unless the x-amz-server-side-encryption header names required_sse_algorithm. Requests that omit the header and rely on the bucket default encryption are denied too."
  type        = bool
  default     = false
  nullable    = false
}

variable "required_sse_algorithm" {
  description = "Server-side encryption algorithm the upload guardrail requires in the x-amz-server-side-encryption header: aws:kms, AES256, or aws:kms:dsse."
  type        = string
  default     = "aws:kms"
  nullable    = false

  validation {
    condition     = contains(["aws:kms", "AES256", "aws:kms:dsse"], var.required_sse_algorithm)
    error_message = "required_sse_algorithm must be aws:kms, AES256, or aws:kms:dsse."
  }
}

variable "deny_incorrect_encryption_key" {
  description = "Add the DenyIncorrectEncryptionKey statement: deny s3:PutObject unless the x-amz-server-side-encryption-aws-kms-key-id header names kms_key_arn. Requires kms_key_arn."
  type        = bool
  default     = false
  nullable    = false
}

variable "kms_key_arn" {
  description = "KMS key ARN (arn:<partition>:kms:<region>:<account>:key/<id>) that uploads must use when deny_incorrect_encryption_key is set. Key IDs and aliases are not accepted because S3 evaluates the condition against the key ARN."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : can(regex("^arn:[a-z][a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/(mrk-)?[a-f0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN of the form arn:<partition>:kms:<region>:<account>:key/<key-id>."
  }
}
