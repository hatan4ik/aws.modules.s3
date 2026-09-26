# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Nothing is hard-coded: the setup module generates a unique bucket
# name, the module is applied with its defaults plus one lifecycle rule and
# force_destroy so teardown can delete the bucket, the results are asserted
# against the real API, and everything is destroyed at the end of the file.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    name_prefix = "s3-it"
  }
}

run "smoke" {
  variables {
    bucket = run.setup.bucket_name
    tags   = run.setup.tags

    # The suite must be able to delete the bucket it created; production
    # callers keep the default of false.
    force_destroy = true

    lifecycle_rules = {
      "expire-noncurrent" = {
        noncurrent_version_expiration          = { noncurrent_days = 30 }
        abort_incomplete_multipart_upload_days = 7
      }
    }
  }

  assert {
    condition     = output.id == run.setup.bucket_name && endswith(output.arn, ":s3:::${run.setup.bucket_name}")
    error_message = "The bucket must exist under the fixture name."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.ignore_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "All four public access blocks must be on."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced" && aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Ownership must be enforced and versioning enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true && output.kms_key_arn == null
    error_message = "Default encryption must be SSE-KMS under the AWS managed key with a Bucket Key."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1 && tolist(output.lifecycle_rule_ids) == tolist(["expire-noncurrent"])
    error_message = "The lifecycle rule must have been accepted."
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && jsondecode(output.policy).Statement[0].Sid == "DenyInsecureTransport"
    error_message = "The deny-insecure-transport policy must be attached."
  }

  assert {
    condition     = output.region != "" && output.hosted_zone_id != "" && output.bucket_regional_domain_name == "${run.setup.bucket_name}.s3.${output.region}.amazonaws.com"
    error_message = "Region, hosted zone, and regional domain name must be resolved from the real bucket."
  }
}
