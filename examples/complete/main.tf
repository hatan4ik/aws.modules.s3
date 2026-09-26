provider "aws" {
  region = var.region
}

locals {
  bucket_arn = "arn:${var.partition}:s3:::${var.bucket}"
}

module "bucket" {
  source = "../../"

  bucket    = var.bucket
  partition = var.partition
  tags      = var.tags

  # -------------------------------------------------------- data protection
  versioning         = "Enabled"
  sse_algorithm      = "aws:kms"
  kms_key_arn        = var.kms_key_arn
  bucket_key_enabled = true

  # Object Lock can only be enabled at creation. GOVERNANCE retention can be
  # bypassed by principals holding s3:BypassGovernanceRetention.
  object_lock = {
    enabled = true
    mode    = "GOVERNANCE"
    days    = 30
  }

  # ------------------------------------------------------ storage management
  lifecycle_rules = {
    "abort-incomplete-uploads" = {
      abort_incomplete_multipart_upload_days = 7
    }
    "tier-reports" = {
      filter = { prefix = "reports/" }
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER_IR" },
      ]
      noncurrent_version_transitions = [{ noncurrent_days = 30, storage_class = "GLACIER_IR" }]
      noncurrent_version_expiration  = { noncurrent_days = 365, newer_noncurrent_versions = 5 }
    }
    "expire-short-lived-exports" = {
      filter     = { prefix = "exports/", tags = { retention = "short" } }
      expiration = { days = 30 }
    }
    "intelligent-tiering-large-objects" = {
      filter      = { object_size_greater_than = 131072 }
      transitions = [{ days = 0, storage_class = "INTELLIGENT_TIERING" }]
    }
  }

  # Acts on objects the rule above moved into INTELLIGENT_TIERING.
  intelligent_tiering_configurations = {
    "archive-after-inactivity" = {
      tierings = [
        { access_tier = "ARCHIVE_ACCESS", days = 90 },
        { access_tier = "DEEP_ARCHIVE_ACCESS", days = 180 },
      ]
    }
  }

  # ---------------------------------------------------------- observability
  logging = {
    target_bucket            = var.log_bucket
    target_prefix            = "${var.bucket}/"
    target_object_key_format = { partitioned = { partition_date_source = "EventTime" } }
  }

  cors_rules = [{
    id              = "browser-uploads"
    allowed_methods = ["GET", "PUT"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["Authorization", "Content-Type", "x-amz-*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }]

  # ------------------------------------------------------------------ policy
  # Uploads must name the bucket's algorithm and key in their headers.
  deny_unencrypted_object_uploads = true
  deny_incorrect_encryption_key   = true

  bucket_policy_statements = {
    ReadReports = {
      principals = { AWS = [var.reader_role_arn] }
      actions    = ["s3:GetObject", "s3:GetObjectVersion"]
      resources  = ["${local.bucket_arn}/reports/*"]
    }
    ListReports = {
      principals = { AWS = [var.reader_role_arn] }
      actions    = ["s3:ListBucket"]
      resources  = [local.bucket_arn]
      conditions = [{ test = "StringLike", variable = "s3:prefix", values = ["reports/*"] }]
    }
  }
}
