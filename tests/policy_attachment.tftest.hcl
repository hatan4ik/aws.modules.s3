# When a bucket policy is attached. aws_s3_bucket_policy.this is counted from
# the inputs alone, so the decision is known at plan time even when the
# rendered document is not. These runs pin the decision in the composition
# that exposed it (a key created in the same configuration) and at every
# boundary of the inputs that contribute a statement.

mock_provider "aws" {}

variables {
  bucket = "orders-data"
}

# A key created alongside the bucket has an ARN that is known only after
# apply. The module receives it as kms_key_arn, the renderer receives it too,
# and the policy resource must still be planned; the default guardrail does
# not name the key, so its document is known as well. Before the fix this plan
# failed with "Invalid count argument".
run "attaches_the_policy_when_the_key_is_created_in_the_same_configuration" {
  command = plan

  module {
    source = "./tests/setup/key-and-bucket"
  }

  assert {
    condition     = output.policy != null && length(jsondecode(output.policy).Statement) == 1 && jsondecode(output.policy).Statement[0].Sid == "DenyInsecureTransport"
    error_message = "The transport guardrail does not depend on the key, so its document must be rendered and attached while the key ARN is still unknown."
  }
}

# The key guardrail names the ARN, so this document is known only after apply.
# The resource is planned regardless, because that follows from the flag, not
# from the document. No assertion can read the unknown document; the run
# passes when the plan succeeds, which it did not before the fix.
run "attaches_the_policy_when_the_key_guardrail_names_a_key_known_after_apply" {
  command = plan

  module {
    source = "./tests/setup/key-and-bucket"
  }

  variables {
    deny_insecure_transport       = false
    deny_incorrect_encryption_key = true
  }
}

run "attaches_no_policy_without_a_guardrail_or_a_statement" {
  command = plan

  variables {
    deny_insecure_transport         = false
    deny_unencrypted_object_uploads = false
    deny_incorrect_encryption_key   = false
    bucket_policy_statements        = {}
    policy_json_override            = null
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 0 && output.policy == null
    error_message = "With every guardrail off, no statement, and no override, no policy resource may be planned."
  }
}

run "attaches_the_policy_for_the_transport_guardrail_alone" {
  command = plan

  variables {
    deny_insecure_transport         = true
    deny_unencrypted_object_uploads = false
    deny_incorrect_encryption_key   = false
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && [for statement in jsondecode(aws_s3_bucket_policy.this[0].policy).Statement : statement.Sid] == ["DenyInsecureTransport"]
    error_message = "The transport guardrail alone must plan one policy resource carrying only its statement."
  }
}

run "attaches_the_policy_for_the_upload_guardrail_alone" {
  command = plan

  variables {
    deny_insecure_transport         = false
    deny_unencrypted_object_uploads = true
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && [for statement in jsondecode(aws_s3_bucket_policy.this[0].policy).Statement : statement.Sid] == ["DenyUnencryptedObjectUploads"]
    error_message = "The upload guardrail alone must plan one policy resource carrying only its statement."
  }
}

run "attaches_the_policy_for_the_key_guardrail_alone" {
  command = plan

  variables {
    deny_insecure_transport       = false
    deny_incorrect_encryption_key = true
    kms_key_arn                   = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && [for statement in jsondecode(aws_s3_bucket_policy.this[0].policy).Statement : statement.Sid] == ["DenyIncorrectEncryptionKey"]
    error_message = "The key guardrail alone must plan one policy resource carrying only its statement."
  }
}

run "attaches_the_policy_for_declared_statements_alone" {
  command = plan

  variables {
    deny_insecure_transport = false
    bucket_policy_statements = {
      ReadOnly = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/reader"] }
        actions    = ["s3:GetObject"]
      }
    }
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && [for statement in jsondecode(aws_s3_bucket_policy.this[0].policy).Statement : statement.Sid] == ["ReadOnly"]
    error_message = "A declared statement alone must plan one policy resource carrying only that statement."
  }
}

run "attaches_the_policy_for_the_override_alone" {
  command = plan

  variables {
    deny_insecure_transport = false
    policy_json_override    = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"CallerOwned\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:DeleteObject\",\"Resource\":\"arn:aws:s3:::orders-data/*\"}]}"
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && aws_s3_bucket_policy.this[0].policy == var.policy_json_override
    error_message = "The override alone must plan one policy resource carrying the caller's document verbatim."
  }
}
