mock_provider "aws" {}

variables {
  bucket = "orders-data"
}

run "rejects_uppercase_bucket_name" {
  command = plan
  variables {
    bucket = "Orders-Data"
  }
  expect_failures = [var.bucket]
}

run "rejects_bucket_name_shorter_than_three_characters" {
  command = plan
  variables {
    bucket = "ab"
  }
  expect_failures = [var.bucket]
}

run "rejects_bucket_name_longer_than_sixty_three_characters" {
  command = plan
  variables {
    bucket = "this-bucket-name-is-sixty-four-characters-long-which-is-too-long1"
  }
  expect_failures = [var.bucket]
}

run "rejects_underscore_in_bucket_name" {
  command = plan
  variables {
    bucket = "orders_data"
  }
  expect_failures = [var.bucket]
}

run "rejects_bucket_name_formatted_as_ip_address" {
  command = plan
  variables {
    bucket = "192.168.0.1"
  }
  expect_failures = [var.bucket]
}

run "rejects_adjacent_dots_in_bucket_name" {
  command = plan
  variables {
    bucket = "orders..data"
  }
  expect_failures = [var.bucket]
}

run "rejects_reserved_bucket_name_prefix" {
  command = plan
  variables {
    bucket = "xn--orders"
  }
  expect_failures = [var.bucket]
}

run "rejects_reserved_bucket_name_suffix" {
  command = plan
  variables {
    bucket = "orders-s3alias"
  }
  expect_failures = [var.bucket]
}

run "rejects_unknown_partition" {
  command = plan
  variables {
    partition = "aws-iso"
  }
  expect_failures = [var.partition]
}

run "rejects_unknown_object_ownership" {
  command = plan
  variables {
    object_ownership = "Public"
  }
  expect_failures = [var.object_ownership]
}

run "rejects_unknown_versioning_state" {
  command = plan
  variables {
    versioning = "On"
  }
  expect_failures = [var.versioning]
}

run "rejects_unknown_sse_algorithm" {
  command = plan
  variables {
    sse_algorithm = "SSE-S3"
  }
  expect_failures = [var.sse_algorithm]
}

run "rejects_kms_alias_instead_of_key_arn" {
  command = plan
  variables {
    kms_key_arn = "alias/orders"
  }
  expect_failures = [var.kms_key_arn]
}

run "rejects_kms_key_with_sse_s3" {
  command = plan
  variables {
    sse_algorithm = "AES256"
    kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }
  expect_failures = [aws_s3_bucket_server_side_encryption_configuration.this]
}

run "rejects_key_guardrail_without_a_key" {
  command = plan
  variables {
    deny_incorrect_encryption_key = true
  }
  expect_failures = [aws_s3_bucket_server_side_encryption_configuration.this]
}

# With no other statement the policy resource is still counted from the flag
# but has no document; it names the missing key too rather than reporting its
# policy argument as missing.
run "rejects_key_guardrail_without_a_key_when_it_is_the_only_statement" {
  command = plan
  variables {
    deny_insecure_transport       = false
    deny_incorrect_encryption_key = true
  }
  expect_failures = [aws_s3_bucket_server_side_encryption_configuration.this, aws_s3_bucket_policy.this]
}

run "rejects_object_lock_mode_outside_governance_and_compliance" {
  command = plan
  variables {
    object_lock = { enabled = true, mode = "LEGAL", days = 1 }
  }
  expect_failures = [var.object_lock]
}

run "rejects_object_lock_retention_without_enabled" {
  command = plan
  variables {
    object_lock = { mode = "GOVERNANCE", days = 1 }
  }
  expect_failures = [var.object_lock]
}

run "rejects_object_lock_retention_with_days_and_years" {
  command = plan
  variables {
    object_lock = { enabled = true, mode = "COMPLIANCE", days = 30, years = 1 }
  }
  expect_failures = [var.object_lock]
}

run "rejects_object_lock_days_without_mode" {
  command = plan
  variables {
    object_lock = { enabled = true, days = 30 }
  }
  expect_failures = [var.object_lock]
}

run "rejects_object_lock_without_versioning" {
  command = plan
  variables {
    versioning  = "Suspended"
    object_lock = { enabled = true }
  }
  expect_failures = [aws_s3_bucket.this, check.versioning_not_enabled]
}

run "rejects_lifecycle_rule_without_action" {
  command = plan
  variables {
    lifecycle_rules = {
      empty = { filter = { prefix = "logs/" } }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_unknown_transition_storage_class" {
  command = plan
  variables {
    lifecycle_rules = {
      archive = { transitions = [{ days = 30, storage_class = "REDUCED_REDUNDANCY" }] }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_transition_with_days_and_date" {
  command = plan
  variables {
    lifecycle_rules = {
      archive = { transitions = [{ days = 30, date = "2030-01-01T00:00:00Z", storage_class = "GLACIER" }] }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_expiration_with_days_and_date" {
  command = plan
  variables {
    lifecycle_rules = {
      expire = { expiration = { days = 30, date = "2030-01-01T00:00:00Z" } }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_expired_delete_marker_with_tag_filter" {
  command = plan
  variables {
    lifecycle_rules = {
      markers = {
        filter     = { tags = { tier = "cold" } }
        expiration = { expired_object_delete_marker = true }
      }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_standard_ia_transition_under_thirty_days" {
  command = plan
  variables {
    lifecycle_rules = {
      archive = { transitions = [{ days = 10, storage_class = "STANDARD_IA" }] }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_inverted_object_size_bounds" {
  command = plan
  variables {
    lifecycle_rules = {
      sized = {
        filter     = { object_size_greater_than = 100, object_size_less_than = 10 }
        expiration = { days = 1 }
      }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_lifecycle_date_without_a_time" {
  command = plan
  variables {
    lifecycle_rules = {
      expire = { expiration = { date = "2030-01-01" } }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_lifecycle_date_not_at_midnight_utc" {
  command = plan
  variables {
    lifecycle_rules = {
      archive = { transitions = [{ date = "2030-01-01T12:00:00Z", storage_class = "GLACIER" }] }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_newer_noncurrent_versions_outside_range" {
  command = plan
  variables {
    lifecycle_rules = {
      versions = { noncurrent_version_expiration = { noncurrent_days = 30, newer_noncurrent_versions = 0 } }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_zero_abort_days" {
  command = plan
  variables {
    lifecycle_rules = {
      uploads = { abort_incomplete_multipart_upload_days = 0 }
    }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_unknown_intelligent_tiering_access_tier" {
  command = plan
  variables {
    intelligent_tiering_configurations = {
      archive = { tierings = [{ access_tier = "GLACIER", days = 90 }] }
    }
  }
  expect_failures = [var.intelligent_tiering_configurations]
}

run "rejects_intelligent_tiering_days_below_minimum" {
  command = plan
  variables {
    intelligent_tiering_configurations = {
      archive = { tierings = [{ access_tier = "DEEP_ARCHIVE_ACCESS", days = 90 }] }
    }
  }
  expect_failures = [var.intelligent_tiering_configurations]
}

run "rejects_intelligent_tiering_without_tierings" {
  command = plan
  variables {
    intelligent_tiering_configurations = {
      archive = { tierings = [] }
    }
  }
  expect_failures = [var.intelligent_tiering_configurations]
}

run "rejects_duplicate_intelligent_tiering_tiers" {
  command = plan
  variables {
    intelligent_tiering_configurations = {
      archive = { tierings = [{ access_tier = "ARCHIVE_ACCESS", days = 90 }, { access_tier = "ARCHIVE_ACCESS", days = 180 }] }
    }
  }
  expect_failures = [var.intelligent_tiering_configurations]
}

run "rejects_unknown_intelligent_tiering_status" {
  command = plan
  variables {
    intelligent_tiering_configurations = {
      archive = { status = "On", tierings = [{ access_tier = "ARCHIVE_ACCESS", days = 90 }] }
    }
  }
  expect_failures = [var.intelligent_tiering_configurations]
}

run "rejects_logging_target_that_is_not_a_bucket_name" {
  command = plan
  variables {
    logging = { target_bucket = "Logs_Bucket" }
  }
  expect_failures = [var.logging]
}

run "rejects_logging_prefix_with_leading_slash" {
  command = plan
  variables {
    logging = { target_bucket = "orders-logs", target_prefix = "/orders-data/" }
  }
  expect_failures = [var.logging]
}

run "rejects_logging_with_both_key_formats" {
  command = plan
  variables {
    logging = { target_bucket = "orders-logs", target_object_key_format = { partitioned = {}, simple = true } }
  }
  expect_failures = [var.logging]
}

run "rejects_logging_key_format_without_a_choice" {
  command = plan
  variables {
    logging = { target_bucket = "orders-logs", target_object_key_format = {} }
  }
  expect_failures = [var.logging]
}

run "rejects_unknown_partition_date_source" {
  command = plan
  variables {
    logging = { target_bucket = "orders-logs", target_object_key_format = { partitioned = { partition_date_source = "RequestTime" } } }
  }
  expect_failures = [var.logging]
}

run "rejects_unknown_cors_method" {
  command = plan
  variables {
    cors_rules = [{ allowed_methods = ["PATCH"], allowed_origins = ["https://app.example.com"] }]
  }
  expect_failures = [var.cors_rules]
}

run "rejects_cors_rule_without_origins" {
  command = plan
  variables {
    cors_rules = [{ allowed_methods = ["GET"], allowed_origins = [] }]
  }
  expect_failures = [var.cors_rules]
}

run "rejects_negative_cors_max_age" {
  command = plan
  variables {
    cors_rules = [{ allowed_methods = ["GET"], allowed_origins = ["https://app.example.com"], max_age_seconds = -1 }]
  }
  expect_failures = [var.cors_rules]
}

run "rejects_policy_override_that_is_not_a_policy" {
  command = plan
  variables {
    policy_json_override = "{}"
  }
  expect_failures = [var.policy_json_override]
}

run "rejects_policy_override_beside_the_transport_guardrail" {
  command = plan
  variables {
    policy_json_override = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"CallerOwned\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:DeleteObject\",\"Resource\":\"arn:aws:s3:::orders-data/*\"}]}"
  }
  expect_failures = [aws_s3_bucket_policy.this]
}

run "rejects_policy_override_beside_declared_statements" {
  command = plan
  variables {
    deny_insecure_transport = false
    policy_json_override    = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"CallerOwned\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:DeleteObject\",\"Resource\":\"arn:aws:s3:::orders-data/*\"}]}"
    bucket_policy_statements = {
      ReadOnly = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/reader"] }
        actions    = ["s3:GetObject"]
      }
    }
  }
  expect_failures = [aws_s3_bucket_policy.this]
}
