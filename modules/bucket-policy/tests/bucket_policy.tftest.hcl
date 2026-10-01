variables {
  bucket_arn = "arn:aws:s3:::orders-data"
}

run "renders_only_the_transport_guardrail_by_default" {
  command = plan

  assert {
    condition     = jsondecode(output.json).Version == "2012-10-17" && length(jsondecode(output.json).Statement) == 1 && output.statement_count == 1
    error_message = "The default document must contain exactly one statement."
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Sid == "DenyInsecureTransport" && jsondecode(output.json).Statement[0].Effect == "Deny" && jsondecode(output.json).Statement[0].Principal == "*"
    error_message = "The transport guardrail must deny every principal."
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Action == ["s3:*"] && jsondecode(output.json).Statement[0].Resource == ["arn:aws:s3:::orders-data", "arn:aws:s3:::orders-data/*"]
    error_message = "The transport guardrail must cover every action on the bucket and its objects."
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The transport guardrail must match requests where aws:SecureTransport is false."
  }
}

run "renders_null_when_nothing_is_declared" {
  command = plan

  variables {
    deny_insecure_transport = false
  }

  assert {
    condition     = output.json == null && output.statement_count == 0
    error_message = "A document without statements must render as null so the caller creates no policy resource."
  }
}

run "denies_uploads_without_the_required_algorithm_header" {
  command = plan

  variables {
    deny_unencrypted_object_uploads = true
    required_sse_algorithm          = "AES256"
  }

  assert {
    condition     = jsondecode(output.json).Statement[1].Sid == "DenyUnencryptedObjectUploads" && jsondecode(output.json).Statement[1].Effect == "Deny" && jsondecode(output.json).Statement[1].Principal == "*"
    error_message = "The upload guardrail must be a deny for every principal, sorted after DenyInsecureTransport."
  }

  assert {
    condition     = jsondecode(output.json).Statement[1].Action == ["s3:PutObject"] && jsondecode(output.json).Statement[1].Resource == ["arn:aws:s3:::orders-data/*"]
    error_message = "The upload guardrail must target PutObject on objects only."
  }

  assert {
    condition     = jsondecode(output.json).Statement[1].Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "AES256"
    error_message = "The upload guardrail must require the declared algorithm in the encryption header."
  }
}

run "denies_uploads_with_a_different_kms_key" {
  command = plan

  variables {
    deny_incorrect_encryption_key = true
    kms_key_arn                   = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Sid == "DenyIncorrectEncryptionKey" && jsondecode(output.json).Statement[1].Sid == "DenyInsecureTransport"
    error_message = "Statements must be sorted by Sid."
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Action == ["s3:PutObject"] && jsondecode(output.json).Statement[0].Condition.StringNotEquals["s3:x-amz-server-side-encryption-aws-kms-key-id"] == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "The key guardrail must deny PutObject unless the header names the declared key."
  }
}

run "rejects_key_guardrail_without_a_key" {
  command = plan

  variables {
    deny_incorrect_encryption_key = true
  }

  expect_failures = [output.json]
}

run "merges_declared_statements_sorted_by_sid_with_grouped_conditions" {
  command = plan

  variables {
    statements = {
      ReadForAnalytics = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:ListBucket", "s3:GetObject"]
        conditions = [
          { test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-abcdef1234"] },
          { test = "StringEquals", variable = "s3:prefix", values = ["reports/", "exports/"] },
          { test = "Bool", variable = "aws:SecureTransport", values = ["true"] },
        ]
      }
      AllowLogDelivery = {
        principals = { Service = ["logging.s3.amazonaws.com"] }
        actions    = ["s3:PutObject"]
        resources  = ["arn:aws:s3:::orders-data/logs/*"]
      }
    }
  }

  assert {
    condition     = [for statement in jsondecode(output.json).Statement : statement.Sid] == ["AllowLogDelivery", "DenyInsecureTransport", "ReadForAnalytics"] && output.statement_count == 3
    error_message = "Guardrails and declared statements must merge into one document sorted by Sid."
  }

  assert {
    condition     = jsondecode(output.json).Statement[0].Principal.Service == ["logging.s3.amazonaws.com"] && jsondecode(output.json).Statement[0].Resource == ["arn:aws:s3:::orders-data/logs/*"] && !contains(keys(jsondecode(output.json).Statement[0]), "Condition")
    error_message = "A statement without conditions must render no Condition key and keep its declared resources."
  }

  assert {
    condition     = jsondecode(output.json).Statement[2].Effect == "Allow" && jsondecode(output.json).Statement[2].Action == ["s3:GetObject", "s3:ListBucket"] && jsondecode(output.json).Statement[2].Resource == ["arn:aws:s3:::orders-data", "arn:aws:s3:::orders-data/*"]
    error_message = "Actions must be sorted and resources must default to the bucket and its objects."
  }

  assert {
    condition     = keys(jsondecode(output.json).Statement[2].Condition) == ["Bool", "StringEquals"] && jsondecode(output.json).Statement[2].Condition.StringEquals["s3:prefix"] == ["exports/", "reports/"] && jsondecode(output.json).Statement[2].Condition.StringEquals["aws:PrincipalOrgID"] == ["o-abcdef1234"] && jsondecode(output.json).Statement[2].Condition.Bool["aws:SecureTransport"] == ["true"]
    error_message = "Conditions must be grouped by test with sorted values."
  }
}

run "renders_deny_statements_for_all_principals" {
  command = plan

  variables {
    statements = {
      DenyObjectDeletion = {
        effect        = "Deny"
        principal_all = true
        actions       = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
        resources     = ["arn:aws:s3:::orders-data/*"]
      }
    }
  }

  assert {
    condition     = jsondecode(output.json).Statement[1].Sid == "DenyObjectDeletion" && jsondecode(output.json).Statement[1].Effect == "Deny" && jsondecode(output.json).Statement[1].Principal == "*"
    error_message = "principal_all must render the wildcard principal, sorted after the transport guardrail."
  }
}

run "rejects_resource_outside_the_bucket" {
  command = plan

  variables {
    statements = {
      ReadOtherBucket = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
        resources  = ["arn:aws:s3:::other-bucket/*"]
      }
    }
  }

  expect_failures = [output.json]
}

run "rejects_sid_that_is_not_alphanumeric" {
  command = plan

  variables {
    statements = {
      "read-only" = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_reserved_guardrail_sid" {
  command = plan

  variables {
    statements = {
      DenyInsecureTransport = {
        principal_all = true
        effect        = "Deny"
        actions       = ["s3:*"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_statement_without_principal" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        actions = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_statement_with_both_principal_forms" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        principal_all = true
        principals    = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions       = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_unknown_principal_type" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        principals = { Account = ["123456789012"] }
        actions    = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_empty_action_set" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = []
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_effect_outside_allow_and_deny" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        effect     = "allow"
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_condition_without_values" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
        conditions = [{ test = "StringEquals", variable = "s3:prefix", values = [] }]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_malformed_bucket_arn" {
  command = plan

  variables {
    bucket_arn = "orders-data"
  }

  expect_failures = [var.bucket_arn]
}

run "rejects_unknown_required_algorithm" {
  command = plan

  variables {
    required_sse_algorithm = "SSE-S3"
  }

  expect_failures = [var.required_sse_algorithm]
}

run "rejects_malformed_kms_key_arn" {
  command = plan

  variables {
    kms_key_arn = "11111111-1111-1111-1111-111111111111"
  }

  expect_failures = [var.kms_key_arn]
}

run "renders_wildcard_allow_scoped_by_a_condition" {
  command = plan

  variables {
    statements = {
      ReadFromOrganization = {
        principal_all = true
        actions       = ["s3:GetObject"]
        conditions    = [{ test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-abcdef1234"] }]
      }
    }
  }

  assert {
    condition     = jsondecode(output.json).Statement[1].Sid == "ReadFromOrganization" && jsondecode(output.json).Statement[1].Principal == "*" && jsondecode(output.json).Statement[1].Condition.StringEquals["aws:PrincipalOrgID"] == ["o-abcdef1234"]
    error_message = "A wildcard Allow carrying a condition must render with its condition."
  }
}

run "rejects_unconditioned_allow_for_all_principals" {
  command = plan

  variables {
    statements = {
      PublicRead = {
        principal_all = true
        actions       = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_unconditioned_allow_for_a_wildcard_identifier" {
  command = plan

  variables {
    statements = {
      PublicRead = {
        principals = { AWS = ["*"] }
        actions    = ["s3:GetObject"]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_repeated_condition_test_and_variable" {
  command = plan

  variables {
    statements = {
      ReadOnly = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
        conditions = [
          { test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-abcdef1234"] },
          { test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-fedcba4321"] },
        ]
      }
    }
  }

  expect_failures = [var.statements]
}

run "rejects_policy_larger_than_the_s3_limit" {
  command = plan

  variables {
    statements = {
      ReadManyPrefixes = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
        resources  = [for index in range(600) : "arn:aws:s3:::orders-data/tenant-${index}/*"]
      }
    }
  }

  expect_failures = [output.json]
}

run "accepts_policy_just_under_the_s3_limit" {
  command = plan

  variables {
    statements = {
      ReadManyPrefixes = {
        principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
        actions    = ["s3:GetObject"]
        resources  = [for index in range(400) : "arn:aws:s3:::orders-data/tenant-${index}/*"]
      }
    }
  }

  assert {
    condition     = length(output.json) <= 20480 && length(output.json) > 15000
    error_message = "A document under 20 KB must render."
  }
}
