mock_provider "aws" {}

variables {
  bucket = "orders-data"
}

run "object_lock_with_a_default_retention_in_days" {
  command = plan

  variables {
    object_lock = { enabled = true, mode = "COMPLIANCE", days = 30 }
  }

  assert {
    condition     = aws_s3_bucket.this.object_lock_enabled == true && length(aws_s3_bucket_object_lock_configuration.this) == 1
    error_message = "Object Lock must be enabled on the bucket and a default retention configured."
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].mode == "COMPLIANCE" && aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].days == 30 && aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].years == null
    error_message = "The default retention must carry the declared mode and days only."
  }
}

run "object_lock_with_a_default_retention_in_years" {
  command = plan

  variables {
    object_lock = { enabled = true, mode = "GOVERNANCE", years = 7 }
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].mode == "GOVERNANCE" && aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].years == 7 && aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].days == null
    error_message = "The default retention must carry the declared mode and years only."
  }
}

run "object_lock_without_a_default_retention" {
  command = plan

  variables {
    object_lock = { enabled = true }
  }

  assert {
    condition     = aws_s3_bucket.this.object_lock_enabled == true && length(aws_s3_bucket_object_lock_configuration.this) == 0
    error_message = "Enabling Object Lock without a mode must not create a retention configuration."
  }
}

run "lifecycle_rules_render_filters_and_actions" {
  command = plan

  variables {
    lifecycle_rules = {
      "expire-logs" = {
        filter                                 = { prefix = "logs/" }
        expiration                             = { days = 90 }
        abort_incomplete_multipart_upload_days = 7
      }
      "archive-reports" = {
        filter                         = { prefix = "reports/", tags = { class = "archive" } }
        transitions                    = [{ days = 30, storage_class = "STANDARD_IA" }, { days = 90, storage_class = "GLACIER" }]
        noncurrent_version_transitions = [{ noncurrent_days = 30, storage_class = "GLACIER_IR", newer_noncurrent_versions = 2 }]
        noncurrent_version_expiration  = { noncurrent_days = 365, newer_noncurrent_versions = 3 }
      }
      "cold-tag" = {
        enabled    = false
        filter     = { tags = { tier = "cold" } }
        expiration = { date = "2030-01-01T00:00:00Z" }
      }
      "large-objects" = {
        filter      = { object_size_greater_than = 1048576 }
        transitions = [{ days = 0, storage_class = "INTELLIGENT_TIERING" }]
      }
      "all-objects" = {
        expiration = { expired_object_delete_marker = true }
      }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1 && [for rule in aws_s3_bucket_lifecycle_configuration.this[0].rule : rule.id] == ["all-objects", "archive-reports", "cold-tag", "expire-logs", "large-objects"]
    error_message = "One lifecycle configuration must carry every rule in id order."
  }

  assert {
    condition     = tolist(output.lifecycle_rule_ids) == tolist(["all-objects", "archive-reports", "cold-tag", "expire-logs", "large-objects"])
    error_message = "lifecycle_rule_ids must list the declared ids sorted."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].filter) == 1 && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].filter[0].and) == 0 && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].filter[0].tag) == 0 && aws_s3_bucket_lifecycle_configuration.this[0].rule[0].expiration[0].expired_object_delete_marker == true
    error_message = "A rule without a filter must render an empty filter and its delete-marker expiration."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this[0].rule[1].filter[0].and[0].prefix == "reports/" && aws_s3_bucket_lifecycle_configuration.this[0].rule[1].filter[0].and[0].tags == tomap({ class = "archive" }) && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[1].filter[0].tag) == 0
    error_message = "A prefix combined with tags must render inside an and block."
  }

  assert {
    condition     = sort([for transition in aws_s3_bucket_lifecycle_configuration.this[0].rule[1].transition : "${transition.days}:${transition.storage_class}"]) == tolist(["30:STANDARD_IA", "90:GLACIER"])
    error_message = "Every declared transition must render with its days and storage class."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.this[0].rule[1].noncurrent_version_transition).noncurrent_days == 30 && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[1].noncurrent_version_transition).storage_class == "GLACIER_IR" && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[1].noncurrent_version_transition).newer_noncurrent_versions == 2
    error_message = "Noncurrent-version transitions must render with days, class, and retained versions."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this[0].rule[1].noncurrent_version_expiration[0].noncurrent_days == 365 && aws_s3_bucket_lifecycle_configuration.this[0].rule[1].noncurrent_version_expiration[0].newer_noncurrent_versions == 3
    error_message = "Noncurrent-version expiration must render with days and retained versions."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this[0].rule[2].status == "Disabled" && aws_s3_bucket_lifecycle_configuration.this[0].rule[2].filter[0].tag[0].key == "tier" && aws_s3_bucket_lifecycle_configuration.this[0].rule[2].filter[0].tag[0].value == "cold" && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[2].filter[0].and) == 0 && aws_s3_bucket_lifecycle_configuration.this[0].rule[2].expiration[0].date == "2030-01-01T00:00:00Z"
    error_message = "A single tag must render as a tag block, a disabled rule as Disabled, and a date expiration verbatim."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this[0].rule[3].filter[0].prefix == "logs/" && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[3].filter[0].and) == 0 && aws_s3_bucket_lifecycle_configuration.this[0].rule[3].expiration[0].days == 90 && aws_s3_bucket_lifecycle_configuration.this[0].rule[3].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "A prefix-only filter must render directly, with its expiration and abort settings."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this[0].rule[4].filter[0].object_size_greater_than == 1048576 && length(aws_s3_bucket_lifecycle_configuration.this[0].rule[4].filter[0].and) == 0 && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[4].transition).days == 0 && one(aws_s3_bucket_lifecycle_configuration.this[0].rule[4].transition).storage_class == "INTELLIGENT_TIERING"
    error_message = "A size-only filter must render directly, with a day-zero transition."
  }
}

run "intelligent_tiering_configurations_render_per_name" {
  command = plan

  variables {
    intelligent_tiering_configurations = {
      archive = {
        filter   = { prefix = "archive/" }
        tierings = [{ access_tier = "ARCHIVE_ACCESS", days = 90 }, { access_tier = "DEEP_ARCHIVE_ACCESS", days = 180 }]
      }
      paused = {
        status   = "Disabled"
        tierings = [{ access_tier = "DEEP_ARCHIVE_ACCESS", days = 365 }]
      }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_intelligent_tiering_configuration.this) == 2 && aws_s3_bucket_intelligent_tiering_configuration.this["archive"].name == "archive" && aws_s3_bucket_intelligent_tiering_configuration.this["archive"].status == "Enabled" && aws_s3_bucket_intelligent_tiering_configuration.this["archive"].filter[0].prefix == "archive/" && length(aws_s3_bucket_intelligent_tiering_configuration.this["archive"].tiering) == 2
    error_message = "Each configuration must render under its key with its filter and tierings."
  }

  assert {
    condition     = aws_s3_bucket_intelligent_tiering_configuration.this["paused"].status == "Disabled" && length(aws_s3_bucket_intelligent_tiering_configuration.this["paused"].filter) == 0 && one(aws_s3_bucket_intelligent_tiering_configuration.this["paused"].tiering).days == 365
    error_message = "A configuration without a filter must render none, and status must pass through."
  }
}

run "logging_with_partitioned_keys" {
  command = plan

  variables {
    logging = {
      target_bucket            = "orders-logs"
      target_prefix            = "orders-data/"
      target_object_key_format = { partitioned = {} }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 1 && aws_s3_bucket_logging.this[0].target_bucket == "orders-logs" && aws_s3_bucket_logging.this[0].target_prefix == "orders-data/"
    error_message = "Logging must target the declared bucket and prefix."
  }

  assert {
    condition     = aws_s3_bucket_logging.this[0].target_object_key_format[0].partitioned_prefix[0].partition_date_source == "EventTime" && length(aws_s3_bucket_logging.this[0].target_object_key_format[0].simple_prefix) == 0
    error_message = "A partitioned key format must default to EventTime and render no simple prefix."
  }
}

run "logging_with_simple_keys_and_no_prefix" {
  command = plan

  variables {
    logging = {
      target_bucket            = "orders-logs"
      target_object_key_format = { simple = true }
    }
  }

  assert {
    condition     = aws_s3_bucket_logging.this[0].target_prefix == "" && length(aws_s3_bucket_logging.this[0].target_object_key_format[0].simple_prefix) == 1 && length(aws_s3_bucket_logging.this[0].target_object_key_format[0].partitioned_prefix) == 0
    error_message = "A simple key format must render the simple prefix block only, with an empty target prefix."
  }
}

run "logging_without_a_key_format" {
  command = plan

  variables {
    logging = { target_bucket = "orders-logs" }
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this[0].target_object_key_format) == 0
    error_message = "No key format block may render unless declared."
  }
}

run "cors_rules_render" {
  command = plan

  variables {
    cors_rules = [
      {
        id              = "app"
        allowed_methods = ["GET", "HEAD"]
        allowed_origins = ["https://app.example.com"]
        allowed_headers = ["Authorization"]
        expose_headers  = ["ETag"]
        max_age_seconds = 3600
      },
      {
        allowed_methods = ["PUT"]
        allowed_origins = ["https://upload.example.com"]
      },
    ]
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1 && length(aws_s3_bucket_cors_configuration.this[0].cors_rule) == 2
    error_message = "One CORS configuration must carry both rules."
  }

  assert {
    condition     = anytrue([for rule in aws_s3_bucket_cors_configuration.this[0].cors_rule : rule.id == "app" ? (rule.max_age_seconds == 3600 && contains(rule.allowed_methods, "GET") && contains(rule.allowed_headers, "Authorization") && contains(rule.expose_headers, "ETag")) : false])
    error_message = "The full rule must render every declared attribute."
  }

  assert {
    condition     = anytrue([for rule in aws_s3_bucket_cors_configuration.this[0].cors_rule : rule.id == null && rule.allowed_headers == null && rule.expose_headers == null && contains(rule.allowed_origins, "https://upload.example.com")])
    error_message = "A minimal rule must render without empty header sets."
  }
}

run "sse_s3_disables_the_bucket_key" {
  command = plan

  variables {
    sse_algorithm = "AES256"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == false && output.sse_algorithm == "AES256"
    error_message = "SSE-S3 must render AES256 with the Bucket Key off."
  }
}

run "dsse_kms_with_a_customer_managed_key" {
  command = plan

  variables {
    sse_algorithm = "aws:kms:dsse"
    kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms:dsse" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true
    error_message = "DSSE-KMS must render the declared key with the Bucket Key on."
  }

  assert {
    condition     = output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "The key ARN must be exposed."
  }
}

run "bucket_key_can_be_disabled_for_kms" {
  command = plan

  variables {
    bucket_key_enabled = false
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == false
    error_message = "bucket_key_enabled = false must render as declared."
  }
}

run "versioning_can_be_disabled_at_creation" {
  command = plan

  variables {
    versioning = "Disabled"
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Disabled" && output.versioning == "Disabled"
    error_message = "Disabled versioning must render and be exposed."
  }

  expect_failures = [check.versioning_not_enabled]
}

run "ownership_can_be_relaxed_for_legacy_writers" {
  command = plan

  variables {
    object_ownership = "ObjectWriter"
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "ObjectWriter"
    error_message = "The declared ownership setting must render."
  }

  expect_failures = [check.ownership_not_enforced]
}

run "force_destroy_and_partition_flow_through" {
  command = plan

  variables {
    force_destroy = true
    partition     = "aws-us-gov"
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == true && jsondecode(output.policy).Statement[0].Resource == ["arn:aws-us-gov:s3:::orders-data", "arn:aws-us-gov:s3:::orders-data/*"]
    error_message = "force_destroy must render and the policy ARN must follow the partition."
  }

  expect_failures = [check.force_destroy_enabled]
}
