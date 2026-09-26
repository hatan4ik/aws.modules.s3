provider "aws" {
  region = var.region
}

locals {
  # Logs of one source bucket land under <source bucket>/ in the log bucket,
  # so one log bucket can serve many sources.
  log_prefix = "${var.data_bucket}/"
}

# The log destination. S3 delivers server access logs only to buckets whose
# default encryption is SSE-S3; with SSE-KMS the delivery service may write
# objects under a key the account cannot read. The destination must also not
# have Object Lock enabled, and it must not log to itself.
module "logs" {
  source = "../../"

  bucket    = var.log_bucket
  partition = var.partition
  tags      = var.tags

  sse_algorithm = "AES256"

  lifecycle_rules = {
    "expire-logs" = {
      expiration                             = { days = var.log_retention_days }
      noncurrent_version_expiration          = { noncurrent_days = 7 }
      abort_incomplete_multipart_upload_days = 7
    }
  }

  # The statement AWS documents for log delivery: the logging service
  # principal may put objects under the source bucket's prefix, and only on
  # behalf of that source bucket in this account.
  bucket_policy_statements = {
    S3ServerAccessLogsPolicy = {
      principals = { Service = ["logging.s3.amazonaws.com"] }
      actions    = ["s3:PutObject"]
      resources  = ["arn:${var.partition}:s3:::${var.log_bucket}/${local.log_prefix}*"]
      conditions = [
        { test = "ArnLike", variable = "aws:SourceArn", values = ["arn:${var.partition}:s3:::${var.data_bucket}"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [var.account_id] },
      ]
    }
  }
}

# The bucket whose requests are logged, with date-partitioned log keys so
# Athena and log processors can prune by day.
module "data" {
  source = "../../"

  bucket    = var.data_bucket
  partition = var.partition
  tags      = var.tags

  logging = {
    target_bucket            = module.logs.id
    target_prefix            = local.log_prefix
    target_object_key_format = { partitioned = { partition_date_source = "EventTime" } }
  }

  # S3 accepts a logging configuration only once the destination grants the
  # logging service principal, and the grant is a policy attached after the
  # log bucket exists.
  depends_on = [module.logs]
}
