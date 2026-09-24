mock_provider "aws" {}

variables {
  bucket = "orders-data"
}

run "composes_guardrails_with_declared_statements_sorted_by_sid" {
  command = plan

  variables {
    kms_key_arn                     = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    deny_unencrypted_object_uploads = true
    deny_incorrect_encryption_key   = true
    bucket_policy_statements = {
      ReadForAnalytics = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject", "s3:ListBucket"]
        conditions = [{ test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-abcdef1234"] }]
      }
      AllowLogDelivery = {
        principals = { Service = ["logging.s3.amazonaws.com"] }
        actions    = ["s3:PutObject"]
        resources  = ["arn:aws:s3:::orders-data/logs/*"]
      }
    }
  }

  assert {
    condition     = [for statement in jsondecode(output.policy).Statement : statement.Sid] == ["AllowLogDelivery", "DenyIncorrectEncryptionKey", "DenyInsecureTransport", "DenyUnencryptedObjectUploads", "ReadForAnalytics"]
    error_message = "Guardrails and declared statements must merge into one document sorted by Sid."
  }

  assert {
    condition     = jsondecode(output.policy).Statement[1].Condition.StringNotEquals["s3:x-amz-server-side-encryption-aws-kms-key-id"] == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111" && jsondecode(output.policy).Statement[3].Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "aws:kms"
    error_message = "The upload guardrails must require the bucket's key and algorithm."
  }

  assert {
    condition     = jsondecode(output.policy).Statement[0].Principal.Service == ["logging.s3.amazonaws.com"] && jsondecode(output.policy).Statement[0].Resource == ["arn:aws:s3:::orders-data/logs/*"]
    error_message = "Declared service principals and resources must render verbatim."
  }

  assert {
    condition     = jsondecode(output.policy).Statement[4].Resource == ["arn:aws:s3:::orders-data", "arn:aws:s3:::orders-data/*"] && jsondecode(output.policy).Statement[4].Condition.StringEquals["aws:PrincipalOrgID"] == ["o-abcdef1234"]
    error_message = "Statement resources must default to the bucket and its objects with conditions grouped by test."
  }

  assert {
    condition     = aws_s3_bucket_policy.this[0].policy == output.policy
    error_message = "The composed document must be the one attached to the bucket."
  }
}

run "upload_guardrail_follows_the_bucket_algorithm" {
  command = plan

  variables {
    sse_algorithm                   = "AES256"
    deny_unencrypted_object_uploads = true
  }

  assert {
    condition     = jsondecode(output.policy).Statement[1].Sid == "DenyUnencryptedObjectUploads" && jsondecode(output.policy).Statement[1].Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "AES256"
    error_message = "The upload guardrail must require the algorithm the bucket encrypts with."
  }
}

run "no_policy_is_attached_when_nothing_is_declared" {
  command = plan

  variables {
    deny_insecure_transport = false
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 0 && output.policy == null
    error_message = "Without guardrails or statements no policy resource may exist."
  }
}

run "caller_supplied_document_replaces_the_composition" {
  command = plan

  variables {
    deny_insecure_transport = false
    policy_json_override    = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"CallerOwned\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:DeleteObject\",\"Resource\":\"arn:aws:s3:::orders-data/*\"}]}"
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1 && jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Sid == "CallerOwned" && output.policy == var.policy_json_override
    error_message = "The override must be attached verbatim and exposed as the policy output."
  }
}
