# One private bucket and the configuration it should never exist without.
# Every optional capability is its own S3 API resource, created only when its
# input is declared, so each concern changes on its own.

resource "aws_s3_bucket" "this" {
  bucket              = var.bucket
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock.enabled

  tags = merge({ Name = var.bucket }, var.tags)

  lifecycle {
    precondition {
      condition     = !var.object_lock.enabled || var.versioning == "Enabled"
      error_message = "object_lock.enabled requires versioning = \"Enabled\": Object Lock protects object versions and S3 rejects it on a bucket without versioning."
    }
  }
}

# Not configurable: a bucket that must serve public objects is a different
# product (CloudFront with origin access control in front of a private bucket)
# and is out of scope; see docs/DESIGN.md.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.bucket

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.bucket

  versioning_configuration {
    status = var.versioning
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }

    # An S3 Bucket Key applies to SSE-KMS only; it has no meaning for SSE-S3.
    bucket_key_enabled = var.sse_algorithm == "AES256" ? false : var.bucket_key_enabled
  }

  lifecycle {
    precondition {
      condition     = var.kms_key_arn == null || var.sse_algorithm != "AES256"
      error_message = "kms_key_arn is only used with sse_algorithm aws:kms or aws:kms:dsse; remove the key or choose a KMS algorithm."
    }

    precondition {
      condition     = !var.deny_incorrect_encryption_key || var.kms_key_arn != null
      error_message = "deny_incorrect_encryption_key requires kms_key_arn: the guardrail denies uploads whose KMS key header names any other key."
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock.mode == null ? 0 : 1

  bucket = aws_s3_bucket.this.bucket

  rule {
    default_retention {
      mode  = var.object_lock.mode
      days  = var.object_lock.days
      years = var.object_lock.years
    }
  }

  # The API rejects an Object Lock configuration until versioning is enabled.
  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # checkov:skip=CKV_AWS_300: Whether a rule aborts incomplete multipart uploads is declared per rule (abort_incomplete_multipart_upload_days); the check cannot see through the dynamic rule block.
  count = length(var.lifecycle_rules) == 0 ? 0 : 1

  bucket = aws_s3_bucket.this.bucket

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.key
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix                   = local.lifecycle_filter_criteria[rule.key] == 1 ? rule.value.filter.prefix : null
        object_size_greater_than = local.lifecycle_filter_criteria[rule.key] == 1 ? rule.value.filter.object_size_greater_than : null
        object_size_less_than    = local.lifecycle_filter_criteria[rule.key] == 1 ? rule.value.filter.object_size_less_than : null

        dynamic "tag" {
          for_each = local.lifecycle_filter_criteria[rule.key] == 1 ? rule.value.filter.tags : {}

          content {
            key   = tag.key
            value = tag.value
          }
        }

        dynamic "and" {
          for_each = local.lifecycle_filter_criteria[rule.key] >= 2 ? [rule.value.filter] : []

          content {
            prefix                   = and.value.prefix
            tags                     = length(and.value.tags) == 0 ? null : and.value.tags
            object_size_greater_than = and.value.object_size_greater_than
            object_size_less_than    = and.value.object_size_less_than
          }
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration == null ? [] : [rule.value.expiration]

        content {
          days                         = expiration.value.days
          date                         = expiration.value.date
          expired_object_delete_marker = expiration.value.expired_object_delete_marker
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions

        content {
          days          = transition.value.days
          date          = transition.value.date
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions

        content {
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          newer_noncurrent_versions = noncurrent_version_transition.value.newer_noncurrent_versions
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration == null ? [] : [rule.value.noncurrent_version_expiration]

        content {
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
          newer_noncurrent_versions = noncurrent_version_expiration.value.newer_noncurrent_versions
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days == null ? [] : [rule.value.abort_incomplete_multipart_upload_days]

        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }

  # Noncurrent-version actions are only accepted once versioning exists.
  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = var.intelligent_tiering_configurations

  bucket = aws_s3_bucket.this.bucket
  name   = each.key
  status = each.value.status

  dynamic "filter" {
    for_each = each.value.filter == null ? [] : [each.value.filter]

    content {
      prefix = filter.value.prefix
      tags   = length(filter.value.tags) == 0 ? null : filter.value.tags
    }
  }

  dynamic "tiering" {
    for_each = each.value.tierings

    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

resource "aws_s3_bucket_logging" "this" {
  count = var.logging == null ? 0 : 1

  bucket        = aws_s3_bucket.this.bucket
  target_bucket = var.logging.target_bucket
  target_prefix = var.logging.target_prefix

  dynamic "target_object_key_format" {
    for_each = var.logging.target_object_key_format == null ? [] : [var.logging.target_object_key_format]

    content {
      dynamic "partitioned_prefix" {
        for_each = target_object_key_format.value.partitioned == null ? [] : [target_object_key_format.value.partitioned]

        content {
          partition_date_source = partitioned_prefix.value.partition_date_source
        }
      }

      dynamic "simple_prefix" {
        for_each = target_object_key_format.value.simple ? [true] : []

        content {}
      }
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) == 0 ? 0 : 1

  bucket = aws_s3_bucket.this.bucket

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      id              = cors_rule.value.id
      allowed_headers = length(cors_rule.value.allowed_headers) == 0 ? null : cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = length(cors_rule.value.expose_headers) == 0 ? null : cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

module "bucket_policy" {
  source = "./modules/bucket-policy"

  bucket_arn                      = local.bucket_arn
  statements                      = var.bucket_policy_statements
  deny_insecure_transport         = var.deny_insecure_transport
  deny_unencrypted_object_uploads = var.deny_unencrypted_object_uploads
  required_sse_algorithm          = var.sse_algorithm
  kms_key_arn                     = var.kms_key_arn
  # The encryption configuration's precondition reports a missing key with one
  # actionable error; the renderer receives a consistent pair so the plan does
  # not carry a second one.
  deny_incorrect_encryption_key = var.deny_incorrect_encryption_key && var.kms_key_arn != null
}

resource "aws_s3_bucket_policy" "this" {
  count = local.policy_json == null ? 0 : 1

  bucket = aws_s3_bucket.this.bucket
  policy = local.policy_json

  lifecycle {
    precondition {
      condition     = var.policy_json_override == null || (length(var.bucket_policy_statements) == 0 && !var.deny_insecure_transport && !var.deny_unencrypted_object_uploads && !var.deny_incorrect_encryption_key)
      error_message = "policy_json_override replaces the composed policy: leave bucket_policy_statements empty and set deny_insecure_transport, deny_unencrypted_object_uploads, and deny_incorrect_encryption_key to false, or drop the override and declare statements instead."
    }
  }

  # S3 evaluates a new policy against the public access block, and the block
  # must exist first so a policy can never open the bucket in between.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
