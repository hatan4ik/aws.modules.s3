mock_provider "aws" {}

variables {
  bucket = "orders-data"
  tags   = { Environment = "test", Owner = "orders" }
}

run "bucket_is_private_and_carries_caller_tags" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "orders-data" && aws_s3_bucket.this.force_destroy == false && aws_s3_bucket.this.object_lock_enabled == false
    error_message = "The bucket must use the declared name, refuse to delete objects, and leave Object Lock off."
  }

  assert {
    condition     = aws_s3_bucket.this.tags == tomap({ Environment = "test", Owner = "orders", Name = "orders-data" })
    error_message = "Caller tags must pass through unchanged with a Name tag added."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.ignore_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "All four public access blocks must be on."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Object ownership must be BucketOwnerEnforced by default so ACLs are disabled."
  }
}

run "versioning_and_kms_encryption_are_on_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be Enabled by default."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true
    error_message = "Default encryption must be SSE-KMS with an S3 Bucket Key."
  }

  assert {
    condition     = output.versioning == "Enabled" && output.sse_algorithm == "aws:kms" && output.kms_key_arn == null
    error_message = "Outputs must report Enabled versioning and SSE-KMS with the AWS managed key."
  }
}

run "policy_denies_insecure_transport_and_nothing_else" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && jsondecode(aws_s3_bucket_policy.this[0].policy).Version == "2012-10-17" && length(jsondecode(aws_s3_bucket_policy.this[0].policy).Statement) == 1
    error_message = "Exactly one policy statement must be attached by default."
  }

  assert {
    condition     = jsondecode(output.policy).Statement[0].Sid == "DenyInsecureTransport" && jsondecode(output.policy).Statement[0].Effect == "Deny" && jsondecode(output.policy).Statement[0].Principal == "*" && jsondecode(output.policy).Statement[0].Action == ["s3:*"]
    error_message = "The default statement must deny every action for every principal."
  }

  assert {
    condition     = jsondecode(output.policy).Statement[0].Resource == ["arn:aws:s3:::orders-data", "arn:aws:s3:::orders-data/*"] && jsondecode(output.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The default statement must cover the bucket and its objects when aws:SecureTransport is false."
  }

  assert {
    condition     = output.policy == aws_s3_bucket_policy.this[0].policy
    error_message = "The policy output must be the document attached to the bucket."
  }
}

run "optional_features_stay_off_until_declared" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.this) == 0 && length(aws_s3_bucket_lifecycle_configuration.this) == 0 && length(aws_s3_bucket_intelligent_tiering_configuration.this) == 0
    error_message = "Object Lock retention, lifecycle rules, and Intelligent-Tiering must not render unless declared."
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 0 && length(aws_s3_bucket_cors_configuration.this) == 0
    error_message = "Logging and CORS must not render unless declared."
  }

  assert {
    condition     = length(output.lifecycle_rule_ids) == 0
    error_message = "lifecycle_rule_ids must be empty without rules."
  }
}

run "warns_when_force_destroy_is_on" {
  command = plan

  variables {
    force_destroy = true
  }

  expect_failures = [check.force_destroy_enabled]
}

run "warns_when_versioning_is_suspended" {
  command = plan

  variables {
    versioning = "Suspended"
  }

  expect_failures = [check.versioning_not_enabled]
}

run "warns_when_ownership_is_not_enforced" {
  command = plan

  variables {
    object_ownership = "BucketOwnerPreferred"
  }

  expect_failures = [check.ownership_not_enforced]
}
