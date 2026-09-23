# Renders one S3 bucket policy document from typed inputs. This module creates
# no resources and declares no provider: it exists so the policy shape has a
# single owner and can be unit-tested with terraform test alone.

locals {
  bucket_resources = [var.bucket_arn, "${var.bucket_arn}/*"]
  object_resources = ["${var.bucket_arn}/*"]

  # Guardrails follow the AWS-documented patterns for requiring TLS and
  # server-side encryption headers. They deny for every principal, so they
  # cannot be undone by an Allow elsewhere in the document.
  guardrail_statements = concat(
    var.deny_insecure_transport ? [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = ["s3:*"]
      Resource  = local.bucket_resources
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }] : [],
    var.deny_unencrypted_object_uploads ? [{
      Sid       = "DenyUnencryptedObjectUploads"
      Effect    = "Deny"
      Principal = "*"
      Action    = ["s3:PutObject"]
      Resource  = local.object_resources
      Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = var.required_sse_algorithm } }
    }] : [],
    var.deny_incorrect_encryption_key ? [{
      Sid       = "DenyIncorrectEncryptionKey"
      Effect    = "Deny"
      Principal = "*"
      Action    = ["s3:PutObject"]
      Resource  = local.object_resources
      Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn } }
    }] : [],
  )

  # A wildcard principal is a string while typed principals are an object, so
  # the two shapes are selected by key rather than by a conditional, which
  # would require both branches to share a type.
  declared_statements = [
    for sid in sort(keys(var.statements)) : merge(
      {
        Sid    = sid
        Effect = var.statements[sid].effect
        Principal = ({
          all   = "*"
          named = { for type in sort(keys(var.statements[sid].principals)) : type => sort(tolist(var.statements[sid].principals[type])) }
        })[var.statements[sid].principal_all ? "all" : "named"]
        Action   = sort(tolist(var.statements[sid].actions))
        Resource = var.statements[sid].resources == null ? local.bucket_resources : sort(tolist(var.statements[sid].resources))
      },
      length(var.statements[sid].conditions) == 0 ? {} : {
        Condition = {
          for test in distinct([for condition in var.statements[sid].conditions : condition.test]) : test => {
            for condition in var.statements[sid].conditions : condition.variable => sort(tolist(condition.values)) if condition.test == test
          }
        }
      },
    )
  ]

  # Sids are unique by construction (reserved guardrail Sids are rejected), so
  # the merged document can be sorted by Sid for a deterministic rendering.
  statements_by_sid = merge(
    { for statement in local.guardrail_statements : statement.Sid => statement },
    { for statement in local.declared_statements : statement.Sid => statement },
  )
  statements = [for sid in sort(keys(local.statements_by_sid)) : local.statements_by_sid[sid]]

  declared_resources = flatten([for statement in values(var.statements) : statement.resources == null ? [] : tolist(statement.resources)])

  json = length(local.statements) == 0 ? null : jsonencode({
    Version   = "2012-10-17"
    Statement = local.statements
  })
}
