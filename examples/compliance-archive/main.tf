provider "aws" {
  region = var.region
}

# A write-once archive: Object Lock in COMPLIANCE mode makes every object
# version immutable for the retention period, for every principal including
# the account root. The retention can be extended per object but never
# shortened or removed, so the bucket cannot be emptied or deleted before the
# last retention expires.
module "archive" {
  source = "../../"

  bucket = var.bucket
  tags   = var.tags

  object_lock = {
    enabled = true
    mode    = "COMPLIANCE"
    years   = var.retention_years
  }

  # Every upload must be encrypted under this key, or it is refused before
  # it can become an immutable record.
  kms_key_arn                     = var.kms_key_arn
  deny_unencrypted_object_uploads = true
  deny_incorrect_encryption_key   = true

  # Immutable records still move to cheaper storage on schedule.
  lifecycle_rules = {
    "archive-records" = {
      transitions = [
        { days = 90, storage_class = "GLACIER_IR" },
        { days = 365, storage_class = "DEEP_ARCHIVE" },
      ]
      noncurrent_version_transitions         = [{ noncurrent_days = 30, storage_class = "DEEP_ARCHIVE" }]
      abort_incomplete_multipart_upload_days = 7
    }
  }
}
