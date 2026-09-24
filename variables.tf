# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "bucket" {
  description = "Name of the bucket, globally unique. 3-63 lowercase letters, digits, dots, and hyphens, starting and ending with a letter or digit, following the general purpose bucket naming rules (no adjacent dots, not shaped like an IP address, no reserved prefix or suffix). Also the Name tag."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket))
    error_message = "bucket must be 3-63 lowercase letters, digits, dots, or hyphens, starting and ending with a letter or digit."
  }

  validation {
    condition     = !can(regex("[.][.]", var.bucket))
    error_message = "bucket must not contain two adjacent dots."
  }

  validation {
    condition     = !can(regex("^[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+$", var.bucket))
    error_message = "bucket must not be formatted like an IP address."
  }

  validation {
    condition     = !can(regex("^(xn--|sthree-|amzn-s3-demo-)", var.bucket))
    error_message = "bucket must not start with the reserved prefixes xn--, sthree-, or amzn-s3-demo-."
  }

  validation {
    condition     = !can(regex("(-s3alias|--ol-s3|[.]mrap|--x-s3|--table-s3)$", var.bucket))
    error_message = "bucket must not end with the reserved suffixes -s3alias, --ol-s3, .mrap, --x-s3, or --table-s3."
  }
}

variable "partition" {
  description = "AWS partition the bucket lives in: aws, aws-cn, or aws-us-gov. The bucket ARN used in the policy is derived from it at plan time, so the module performs no lookups."
  type        = string
  default     = "aws"
  nullable    = false

  validation {
    condition     = contains(["aws", "aws-cn", "aws-us-gov"], var.partition)
    error_message = "partition must be aws, aws-cn, or aws-us-gov."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket together with every object and object version in it. Keep false for data you cannot recreate; the force_destroy_enabled check warns on every plan while it is true."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Tags applied to the bucket. The module adds a Name tag equal to the bucket name unless you set one; caller tags are never overridden."
  type        = map(string)
  default     = {}
  nullable    = false
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

variable "object_ownership" {
  description = "Object Ownership setting: BucketOwnerEnforced (ACLs disabled, the default), BucketOwnerPreferred, or ObjectWriter. The other two values re-enable ACLs and trigger the ownership_not_enforced check on every plan."
  type        = string
  default     = "BucketOwnerEnforced"
  nullable    = false

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "object_ownership must be BucketOwnerEnforced, BucketOwnerPreferred, or ObjectWriter."
  }
}

# ---------------------------------------------------------------------------
# Data protection
# ---------------------------------------------------------------------------

variable "versioning" {
  description = "Versioning state: Enabled (default), Suspended, or Disabled. S3 accepts Disabled only on a bucket that has never been versioned; use Suspended on an existing bucket. Object Lock requires Enabled. Anything but Enabled triggers the versioning_not_enabled check."
  type        = string
  default     = "Enabled"
  nullable    = false

  validation {
    condition     = contains(["Enabled", "Suspended", "Disabled"], var.versioning)
    error_message = "versioning must be Enabled, Suspended, or Disabled."
  }
}

variable "sse_algorithm" {
  description = "Default server-side encryption for new objects: aws:kms (SSE-KMS, default), AES256 (SSE-S3), or aws:kms:dsse (dual-layer SSE-KMS). Also the algorithm the deny_unencrypted_object_uploads guardrail requires in upload headers."
  type        = string
  default     = "aws:kms"
  nullable    = false

  validation {
    condition     = contains(["aws:kms", "AES256", "aws:kms:dsse"], var.sse_algorithm)
    error_message = "sse_algorithm must be aws:kms, AES256, or aws:kms:dsse."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer managed KMS key for aws:kms and aws:kms:dsse (arn:<partition>:kms:<region>:<account>:key/<id>). Null uses the AWS managed key aws/s3. Not allowed with AES256. Required by deny_incorrect_encryption_key."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null ? true : can(regex("^arn:[a-z][a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/(mrk-)?[a-f0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN of the form arn:<partition>:kms:<region>:<account>:key/<key-id>; aliases and bare key IDs are not accepted because the policy guardrail compares the ARN."
  }
}

variable "bucket_key_enabled" {
  description = "Use an S3 Bucket Key so SSE-KMS objects share data keys and KMS requests drop by up to 99 percent. Only meaningful for aws:kms and aws:kms:dsse; rendered as false with AES256."
  type        = bool
  default     = true
  nullable    = false
}

variable "object_lock" {
  description = "Object Lock. enabled can only be set when the bucket is created and requires versioning = Enabled. mode (GOVERNANCE or COMPLIANCE) with exactly one of days or years adds a default retention period for new objects; omit mode to enable Object Lock without a default retention."
  type = object({
    enabled = optional(bool, false)
    mode    = optional(string)
    days    = optional(number)
    years   = optional(number)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.object_lock.mode == null ? true : contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock.mode)
    error_message = "object_lock.mode must be GOVERNANCE or COMPLIANCE."
  }

  validation {
    condition     = var.object_lock.mode == null ? true : var.object_lock.enabled
    error_message = "object_lock.mode sets a default retention and requires object_lock.enabled = true."
  }

  validation {
    condition     = var.object_lock.mode == null ? (var.object_lock.days == null && var.object_lock.years == null) : ((var.object_lock.days == null) != (var.object_lock.years == null))
    error_message = "object_lock default retention needs mode with exactly one of days or years; days and years are only valid together with mode."
  }

  validation {
    condition     = (var.object_lock.days == null ? true : var.object_lock.days >= 1) && (var.object_lock.years == null ? true : var.object_lock.years >= 1)
    error_message = "object_lock.days and object_lock.years must be at least 1."
  }
}

# ---------------------------------------------------------------------------
# Storage management
# ---------------------------------------------------------------------------

variable "lifecycle_rules" {
  description = "Lifecycle rules keyed by rule id. Each rule needs at least one action: expiration (exactly one of days, date, or expired_object_delete_marker), transitions (exactly one of days or date each), noncurrent_version_transitions, noncurrent_version_expiration, or abort_incomplete_multipart_upload_days. An omitted filter applies the rule to every object; prefix, tags, and object size bounds combine with AND. Dates are RFC 3339 timestamps at midnight UTC (YYYY-MM-DDT00:00:00Z)."
  type = map(object({
    enabled = optional(bool, true)
    filter = optional(object({
      prefix                   = optional(string)
      tags                     = optional(map(string), {})
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
    }))
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })), [])
    noncurrent_version_transitions = optional(list(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
      storage_class             = string
    })), [])
    noncurrent_version_expiration = optional(object({
      noncurrent_days           = number
      newer_noncurrent_versions = optional(number)
    }))
    abort_incomplete_multipart_upload_days = optional(number)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for id in keys(var.lifecycle_rules) : length(id) >= 1 && length(id) <= 255])
    error_message = "lifecycle_rules keys are rule ids and must be 1-255 characters."
  }

  validation {
    condition = alltrue([for rule in values(var.lifecycle_rules) :
      rule.expiration != null || length(rule.transitions) > 0 || length(rule.noncurrent_version_transitions) > 0 || rule.noncurrent_version_expiration != null || rule.abort_incomplete_multipart_upload_days != null
    ])
    error_message = "Every lifecycle rule needs at least one action: expiration, transitions, noncurrent_version_transitions, noncurrent_version_expiration, or abort_incomplete_multipart_upload_days."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      [for transition in rule.transitions : contains(["GLACIER", "GLACIER_IR", "DEEP_ARCHIVE", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING"], transition.storage_class)],
      [for transition in rule.noncurrent_version_transitions : contains(["GLACIER", "GLACIER_IR", "DEEP_ARCHIVE", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING"], transition.storage_class)],
    ]]))
    error_message = "Transition storage_class must be GLACIER, GLACIER_IR, DEEP_ARCHIVE, STANDARD_IA, ONEZONE_IA, or INTELLIGENT_TIERING."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      for transition in rule.transitions : (transition.days == null) != (transition.date == null)
    ]]))
    error_message = "lifecycle_rules[*].transitions entries need exactly one of days or date."
  }

  validation {
    condition = alltrue([for rule in values(var.lifecycle_rules) : rule.expiration == null ? true : (
      (rule.expiration.days != null ? 1 : 0) + (rule.expiration.date != null ? 1 : 0) + (rule.expiration.expired_object_delete_marker == true ? 1 : 0) == 1
    )])
    error_message = "lifecycle_rules[*].expiration needs exactly one of days, date, or expired_object_delete_marker = true."
  }

  validation {
    condition = alltrue([for rule in values(var.lifecycle_rules) : rule.expiration == null ? true : (
      rule.expiration.expired_object_delete_marker != true || (rule.filter == null ? true : length(rule.filter.tags) == 0)
    )])
    error_message = "expired_object_delete_marker cannot be combined with a tag filter; S3 rejects the rule."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      rule.expiration == null ? true : (rule.expiration.days == null ? true : rule.expiration.days >= 1),
      rule.abort_incomplete_multipart_upload_days == null ? true : rule.abort_incomplete_multipart_upload_days >= 1,
      rule.noncurrent_version_expiration == null ? true : rule.noncurrent_version_expiration.noncurrent_days >= 1,
      [for transition in rule.transitions : transition.days == null ? true : transition.days >= 0],
      [for transition in rule.noncurrent_version_transitions : transition.noncurrent_days >= 0],
    ]]))
    error_message = "Lifecycle day counts must be whole days: expiration.days, abort_incomplete_multipart_upload_days, and noncurrent_version_expiration.noncurrent_days at least 1; transition days at least 0."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      rule.noncurrent_version_expiration == null ? true : (rule.noncurrent_version_expiration.newer_noncurrent_versions == null ? true : (rule.noncurrent_version_expiration.newer_noncurrent_versions >= 1 && rule.noncurrent_version_expiration.newer_noncurrent_versions <= 100)),
      [for transition in rule.noncurrent_version_transitions : transition.newer_noncurrent_versions == null ? true : (transition.newer_noncurrent_versions >= 1 && transition.newer_noncurrent_versions <= 100)],
    ]]))
    error_message = "newer_noncurrent_versions must be between 1 and 100."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      [for transition in rule.transitions : contains(["STANDARD_IA", "ONEZONE_IA"], transition.storage_class) && transition.days != null ? transition.days >= 30 : true],
      [for transition in rule.noncurrent_version_transitions : contains(["STANDARD_IA", "ONEZONE_IA"], transition.storage_class) ? transition.noncurrent_days >= 30 : true],
    ]]))
    error_message = "Transitions to STANDARD_IA or ONEZONE_IA need at least 30 days; S3 rejects shorter periods."
  }

  validation {
    condition = alltrue(flatten([for rule in values(var.lifecycle_rules) : [
      rule.expiration == null ? true : (rule.expiration.date == null ? true : can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T00:00:00Z$", rule.expiration.date))),
      [for transition in rule.transitions : transition.date == null ? true : can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T00:00:00Z$", transition.date))],
    ]]))
    error_message = "Lifecycle dates must be RFC 3339 timestamps at midnight UTC (YYYY-MM-DDT00:00:00Z); S3 accepts no other time of day and the provider rejects a bare date."
  }

  validation {
    condition = alltrue([for rule in values(var.lifecycle_rules) : rule.filter == null ? true : (
      (rule.filter.object_size_greater_than == null ? true : rule.filter.object_size_greater_than >= 0) &&
      (rule.filter.object_size_less_than == null ? true : rule.filter.object_size_less_than >= 1) &&
      (rule.filter.object_size_greater_than == null || rule.filter.object_size_less_than == null ? true : rule.filter.object_size_greater_than < rule.filter.object_size_less_than)
    )])
    error_message = "filter.object_size_greater_than must be at least 0, filter.object_size_less_than at least 1, and the lower bound must be below the upper bound."
  }
}

variable "intelligent_tiering_configurations" {
  description = "Intelligent-Tiering archive configurations keyed by configuration name: status (Enabled or Disabled), an optional prefix and tags filter, and one tiering per archive tier (ARCHIVE_ACCESS after 90-730 days, DEEP_ARCHIVE_ACCESS after 180-730 days). Objects must be stored in the INTELLIGENT_TIERING class, for example through a lifecycle transition, for a configuration to act."
  type = map(object({
    status = optional(string, "Enabled")
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string), {})
    }))
    tierings = list(object({
      access_tier = string
      days        = number
    }))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for configuration in values(var.intelligent_tiering_configurations) : contains(["Enabled", "Disabled"], configuration.status)])
    error_message = "intelligent_tiering_configurations[*].status must be Enabled or Disabled."
  }

  validation {
    condition     = alltrue([for configuration in values(var.intelligent_tiering_configurations) : length(configuration.tierings) >= 1 && length(configuration.tierings) <= 2])
    error_message = "Each Intelligent-Tiering configuration needs one or two tierings (ARCHIVE_ACCESS and DEEP_ARCHIVE_ACCESS)."
  }

  validation {
    condition = alltrue(flatten([for configuration in values(var.intelligent_tiering_configurations) : [
      for tiering in configuration.tierings : contains(["ARCHIVE_ACCESS", "DEEP_ARCHIVE_ACCESS"], tiering.access_tier)
    ]]))
    error_message = "tierings[*].access_tier must be ARCHIVE_ACCESS or DEEP_ARCHIVE_ACCESS."
  }

  validation {
    condition     = alltrue([for configuration in values(var.intelligent_tiering_configurations) : length(distinct([for tiering in configuration.tierings : tiering.access_tier])) == length(configuration.tierings)])
    error_message = "Each access tier may appear once per Intelligent-Tiering configuration."
  }

  validation {
    condition = alltrue(flatten([for configuration in values(var.intelligent_tiering_configurations) : [
      for tiering in configuration.tierings : tiering.days >= (tiering.access_tier == "DEEP_ARCHIVE_ACCESS" ? 180 : 90) && tiering.days <= 730
    ]]))
    error_message = "tierings[*].days must be 90-730 for ARCHIVE_ACCESS and 180-730 for DEEP_ARCHIVE_ACCESS."
  }
}

# ---------------------------------------------------------------------------
# Observability and web
# ---------------------------------------------------------------------------

variable "logging" {
  description = "Server access logging: the destination bucket (it must allow logging.s3.amazonaws.com to put objects; see examples/access-logging), an optional key prefix, and an optional target object key format (partitioned by EventTime or DeliveryTime, or simple). Null disables logging."
  type = object({
    target_bucket = string
    target_prefix = optional(string, "")
    target_object_key_format = optional(object({
      partitioned = optional(object({
        partition_date_source = optional(string, "EventTime")
      }))
      simple = optional(bool, false)
    }))
  })
  default = null

  validation {
    condition     = var.logging == null ? true : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.logging.target_bucket))
    error_message = "logging.target_bucket must be a bucket name (3-63 lowercase letters, digits, dots, or hyphens)."
  }

  validation {
    condition     = var.logging == null ? true : !startswith(var.logging.target_prefix, "/")
    error_message = "logging.target_prefix must not start with a slash; S3 would create an empty top-level folder in the log key."
  }

  validation {
    condition     = var.logging == null ? true : (var.logging.target_object_key_format == null ? true : (var.logging.target_object_key_format.partitioned != null) != var.logging.target_object_key_format.simple)
    error_message = "logging.target_object_key_format needs exactly one of partitioned or simple = true."
  }

  validation {
    condition     = var.logging == null ? true : (var.logging.target_object_key_format == null ? true : (var.logging.target_object_key_format.partitioned == null ? true : contains(["EventTime", "DeliveryTime"], var.logging.target_object_key_format.partitioned.partition_date_source)))
    error_message = "logging.target_object_key_format.partitioned.partition_date_source must be EventTime or DeliveryTime."
  }
}

variable "cors_rules" {
  description = "CORS rules, at most 100. Each names the allowed origins and methods (GET, PUT, HEAD, POST, DELETE), optional allowed request headers and exposed response headers, an optional id, and an optional max_age_seconds for preflight caching. Empty disables CORS."
  type = list(object({
    id              = optional(string)
    allowed_headers = optional(set(string), [])
    allowed_methods = set(string)
    allowed_origins = set(string)
    expose_headers  = optional(set(string), [])
    max_age_seconds = optional(number)
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(var.cors_rules) <= 100
    error_message = "S3 accepts at most 100 CORS rules per bucket."
  }

  validation {
    condition     = alltrue([for rule in var.cors_rules : length(rule.allowed_origins) > 0 && length(rule.allowed_methods) > 0])
    error_message = "Every CORS rule needs at least one allowed origin and one allowed method."
  }

  validation {
    condition     = alltrue(flatten([for rule in var.cors_rules : [for method in rule.allowed_methods : contains(["GET", "PUT", "HEAD", "POST", "DELETE"], method)]]))
    error_message = "cors_rules[*].allowed_methods entries must be GET, PUT, HEAD, POST, or DELETE."
  }

  validation {
    condition     = alltrue([for rule in var.cors_rules : rule.max_age_seconds == null ? true : rule.max_age_seconds >= 0])
    error_message = "cors_rules[*].max_age_seconds must be at least 0."
  }
}

# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------

variable "bucket_policy_statements" {
  description = "Bucket policy statements keyed by alphanumeric Sid, merged with the enabled guardrails and rendered by modules/bucket-policy. Each names principals by type (AWS, Service, Federated, CanonicalUser) or sets principal_all, lists actions, optionally restricts resources to the bucket or paths under it (default: the bucket and its objects), and may add conditions."
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
}

variable "deny_insecure_transport" {
  description = "Add the DenyInsecureTransport statement: deny every S3 action on the bucket and its objects when the request does not use TLS."
  type        = bool
  default     = true
  nullable    = false
}

variable "deny_unencrypted_object_uploads" {
  description = "Add the DenyUnencryptedObjectUploads statement: deny s3:PutObject unless the x-amz-server-side-encryption header names sse_algorithm. Clients must send the header; relying on default encryption is denied too."
  type        = bool
  default     = false
  nullable    = false
}

variable "deny_incorrect_encryption_key" {
  description = "Add the DenyIncorrectEncryptionKey statement: deny s3:PutObject unless the x-amz-server-side-encryption-aws-kms-key-id header names kms_key_arn. Requires kms_key_arn."
  type        = bool
  default     = false
  nullable    = false
}

variable "policy_json_override" {
  description = "Complete bucket policy document that replaces the composed one. When set, bucket_policy_statements must be empty and deny_insecure_transport, deny_unencrypted_object_uploads, and deny_incorrect_encryption_key must be false, so taking over the policy is an explicit choice."
  type        = string
  default     = null

  validation {
    condition     = var.policy_json_override == null ? true : can(jsondecode(var.policy_json_override).Statement)
    error_message = "policy_json_override must be a JSON policy document with a Statement element."
  }
}
