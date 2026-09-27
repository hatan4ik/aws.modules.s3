# Upgrading from 0.1.x to 1.0.0

## What changed and why

Version 0.1.x created one private bucket encrypted with a required customer managed KMS key, with a boolean for versioning, a two-field lifecycle rule shape, an Object Lock block that demanded a retention in days, and a raw policy string. Version 1.0.0 keeps the same bucket and the same resource addresses and opens every other decision to the caller: the encryption algorithm and key, the three versioning states, a typed lifecycle rule with filters and transitions, Object Lock with or without a default retention in days or years, Intelligent-Tiering, server access logging, CORS, and a bucket policy composed from typed statements and guardrails by `modules/bucket-policy`. It validates every input at plan time and ships with tests, examples, and an integration suite. The reasons, and the table of 0.1.x behaviours that were replaced, are in [DESIGN.md](DESIGN.md). This guide moves an existing 0.1.x consumer onto 1.0.0 without replacing the bucket or touching its objects.

## Input mapping

Root inputs of 0.1.2:

| 0.1.x input | 1.0.0 equivalent |
| --- | --- |
| `bucket_name` | `bucket`. Same value. Now validated against the general purpose bucket naming rules at plan time. |
| `kms_key_arn` (required) | `kms_key_arn`, now optional. Keep the same ARN to preserve the existing encryption configuration; `sse_algorithm` defaults to `aws:kms` and `bucket_key_enabled` to `true`, which is what 0.1.x rendered. Dropping the key switches the bucket to the AWS managed `aws/s3` key in place. |
| `force_destroy` | `force_destroy`, unchanged. `true` now raises the advisory `force_destroy_enabled` check on every plan. |
| `versioning_enabled` | `versioning`. `true` becomes `"Enabled"` (the default, so the argument can be omitted); `false` becomes `"Suspended"`, which is what 0.1.x rendered for `false`. `"Disabled"` is new and only valid on a bucket that has never been versioned. Anything but `Enabled` raises the advisory `versioning_not_enabled` check. |
| `object_lock = { enabled, retention_mode, retention_days }` | `object_lock = { enabled, mode, days }`. `retention_mode` is `mode`, `retention_days` is `days`, and `years` is an alternative to `days`. 0.1.x required a retention whenever `enabled` was true; 1.0.0 accepts `{ enabled = true }` alone, which enables Object Lock without a default retention. The precondition that Object Lock needs `versioning = "Enabled"` moved from `terraform_data.input_contract` to `aws_s3_bucket.this`. |
| `bucket_policy_json` | `policy_json_override` for the same behaviour: the document is attached verbatim and nothing is composed. It must be paired with `deny_insecure_transport = false`, because the override and the composition are mutually exclusive by design. Prefer moving the document's statements into `bucket_policy_statements` so the `DenyInsecureTransport` guardrail is added for you (see [Preserving existing resources](#preserving-existing-resources)). |
| `lifecycle_rules = { <id> = { noncurrent_version_expiration_days, abort_incomplete_multipart_days } }` | `lifecycle_rules = { <id> = { noncurrent_version_expiration = { noncurrent_days = <n> }, abort_incomplete_multipart_upload_days = <n> } }`. Keep the same ids: a rule is identified by its id inside one `aws_s3_bucket_lifecycle_configuration` resource, so an unchanged id with the same settings produces no diff. Filters, expirations, and transitions are new and optional. |
| `tags` | `tags`, unchanged shape. The module now adds a `Name` tag equal to `bucket` unless you set `Name` yourself. |

Outputs of 0.1.2:

| 0.1.x output | 1.0.0 equivalent |
| --- | --- |
| `id` | `id`, unchanged. |
| `arn` | `arn`, unchanged. |
| `regional_domain_name` | `bucket_regional_domain_name`. |

New in 1.0.0, all optional: the inputs `partition`, `object_ownership`, `sse_algorithm`, `bucket_key_enabled`, `object_lock.years`, the full `lifecycle_rules` shape, `intelligent_tiering_configurations`, `logging`, `cors_rules`, `bucket_policy_statements`, `deny_insecure_transport`, `deny_unencrypted_object_uploads`, `deny_incorrect_encryption_key`; the outputs `bucket_domain_name`, `hosted_zone_id`, `region`, `policy`, `lifecycle_rule_ids`, `versioning`, `sse_algorithm`, and `kms_key_arn`.

A 0.1.x call and its 1.0.0 rewrite, for a consumer whose block is `module "bucket"`:

```hcl
# 0.1.2
module "bucket" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git?ref=v0.1.2"

  bucket_name        = "orders-data-123456789012"
  kms_key_arn        = aws_kms_key.orders.arn
  versioning_enabled = true

  lifecycle_rules = {
    "expire-noncurrent" = {
      noncurrent_version_expiration_days = 90
      abort_incomplete_multipart_days    = 7
    }
  }

  tags = var.tags
}

# 1.0.0
module "bucket" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git?ref=<commit-sha>" # v1.0.0

  bucket      = "orders-data-123456789012"
  kms_key_arn = aws_kms_key.orders.arn
  # versioning = "Enabled" is the default.

  lifecycle_rules = {
    "expire-noncurrent" = {
      noncurrent_version_expiration          = { noncurrent_days = 90 }
      abort_incomplete_multipart_upload_days = 7
    }
  }

  tags = var.tags
}
```

`module.bucket.regional_domain_name` becomes `module.bucket.bucket_regional_domain_name`.

## Preserving existing resources

A bucket is identified by its name, and 1.0.0 sends S3 the same configuration for the same inputs, so the bucket is not replaced and no object is touched. What changes, all in place and all expected:

- The `Name` tag is added to the bucket unless your `tags` already carry one.
- A bucket policy is attached. 0.1.x attached `aws_s3_bucket_policy.this[0]` only when `bucket_policy_json` was set; 1.0.0 attaches one by default containing the `DenyInsecureTransport` statement, which denies every request that does not use TLS. For a consumer that had no policy the plan shows one new `aws_s3_bucket_policy.this[0]`. Clients that already use HTTPS, which includes every AWS SDK and CLI by default, are unaffected. To keep the bucket exactly as it was, set `deny_insecure_transport = false` and no policy resource is created.
- A consumer that had `bucket_policy_json` sees the policy updated in place. With `policy_json_override` and `deny_insecure_transport = false` the document is unchanged. With the statements moved into `bucket_policy_statements` the document is re-rendered: statements sorted by `Sid`, lists sorted, and the `DenyInsecureTransport` statement added. Review the diff; it is a change to the attached document, not to the bucket.
- `versioning_enabled = false` becomes `versioning = "Suspended"` with no diff. Do not choose `"Disabled"` for an existing bucket: S3 rejects it once a bucket has ever been versioned.
- Object Lock cannot be enabled or disabled on an existing bucket, in either version. Keep `object_lock.enabled` as it was; changing it forces a replacement of the bucket, which the plan shows as `must be replaced`.
- The lifecycle configuration is unchanged when the rule ids and their settings carry over. 1.0.0 renders the same `filter {}` and `Enabled` status that 0.1.x did for a rule without a filter.

Nothing else changes for a bucket that keeps its key.

## State addresses

Every resource address is the same in both versions, so no `moved` blocks are needed. For a consumer block named `module.bucket`:

| 0.1.2 address | 1.0.0 address |
| --- | --- |
| `module.bucket.aws_s3_bucket.this` | `module.bucket.aws_s3_bucket.this` (unchanged) |
| `module.bucket.aws_s3_bucket_public_access_block.this` | `module.bucket.aws_s3_bucket_public_access_block.this` (unchanged) |
| `module.bucket.aws_s3_bucket_ownership_controls.this` | `module.bucket.aws_s3_bucket_ownership_controls.this` (unchanged) |
| `module.bucket.aws_s3_bucket_versioning.this` | `module.bucket.aws_s3_bucket_versioning.this` (unchanged) |
| `module.bucket.aws_s3_bucket_server_side_encryption_configuration.this` | `module.bucket.aws_s3_bucket_server_side_encryption_configuration.this` (unchanged) |
| `module.bucket.aws_s3_bucket_object_lock_configuration.this[0]` | `module.bucket.aws_s3_bucket_object_lock_configuration.this[0]` (unchanged; exists when `object_lock.mode` is set, as it did when `retention_mode` was) |
| `module.bucket.aws_s3_bucket_lifecycle_configuration.this[0]` | `module.bucket.aws_s3_bucket_lifecycle_configuration.this[0]` (unchanged) |
| `module.bucket.aws_s3_bucket_policy.this[0]` | `module.bucket.aws_s3_bucket_policy.this[0]` (unchanged; now created by default) |
| `module.bucket.terraform_data.input_contract` | Removed. The resource held a validation and nothing else; the plan destroys it, which touches nothing in AWS. |

New in 1.0.0 and created only when their input is declared: `aws_s3_bucket_intelligent_tiering_configuration.this[<name>]`, `aws_s3_bucket_logging.this[0]`, and `aws_s3_bucket_cors_configuration.this[0]`. The policy document itself is rendered by `module.bucket.module.bucket_policy`, which has no resources and therefore no state.

## Procedure

1. Pin the 1.0.0 release: copy the commit SHA of tag `v1.0.0` into `?ref=<commit-sha>` and put the tag in a trailing comment.
2. Rewrite the module block with the tables above: `bucket_name` to `bucket`, `versioning_enabled` to `versioning` (or drop it for `true`), `object_lock.retention_mode` and `retention_days` to `mode` and `days`, each lifecycle rule to the typed shape with the same id, and `bucket_policy_json` to `policy_json_override` plus `deny_insecure_transport = false`, or to `bucket_policy_statements`.
3. Update references to the renamed output (`regional_domain_name` to `bucket_regional_domain_name`).
4. Decide whether the bucket gets the `DenyInsecureTransport` policy (the default) or keeps no policy (`deny_insecure_transport = false`).
5. Run `terraform init -upgrade` to fetch the new module source, then `terraform plan`.
6. Verify the plan. There must be no replacement of `aws_s3_bucket.this` and no change to the versioning, encryption, ownership, public access block, or Object Lock resources. Expect the `Name` tag update in place, `terraform_data.input_contract` destroyed, the lifecycle configuration unchanged, and, unless you opted out, `aws_s3_bucket_policy.this[0]` created or updated in place. If the bucket shows `must be replaced`, compare `bucket` and `object_lock.enabled` with the running bucket before applying: those two are the only arguments that force a new bucket.
7. Apply.
