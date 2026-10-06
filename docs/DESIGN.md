# Design: aws.modules.s3 v1

Status: accepted 2026-09-23. Supersedes the v0.1.x "KMS-only bucket" design.

## Purpose

`aws.modules.s3` provisions **one** private Amazon S3 bucket together with the
configuration a bucket should never exist without: a public access block,
ownership controls, versioning, default server-side encryption, and a bucket
policy that refuses unencrypted transport. Every further capability of a
bucket (Object Lock, lifecycle rules, intelligent tiering, server access
logging, CORS, additional policy statements and upload guardrails) is a typed,
optional input that is off until declared. The module is secure by default,
explicit by declaration, and composable: the bucket policy is rendered by a
pure submodule that callers can use on its own, and the whole composition can
be replaced by a caller-supplied policy document.

The module deliberately does **not** create KMS keys, log buckets, replication
roles, notification targets, or IAM identities. Those are separate concerns with
separate lifecycles and owners. The module consumes their identifiers.

## Why the v0.1.x design was replaced

| v0.1.x behaviour | Problem | v1 decision |
|---|---|---|
| `kms_key_arn` was required; SSE-KMS with a customer managed key was the only encryption option. | Buckets that legitimately use SSE-S3 (server access log targets, low-sensitivity data, accounts without a key hierarchy) could not use the module, and the AWS-managed `aws/s3` key was unreachable. | `sse_algorithm` (`aws:kms` default, `AES256`, `aws:kms:dsse`) with an optional `kms_key_arn`. KMS with a bucket key stays the default. |
| `lifecycle_rules` carried two fields (`noncurrent_version_expiration_days`, `abort_incomplete_multipart_days`) and no filter. | Transitions, expirations, size and tag filters, and per-rule status were impossible; every rule applied to the whole bucket. | Typed `lifecycle_rules` map keyed by rule id with filter, expiration, transitions, noncurrent-version actions, and abort settings, validated at plan time. |
| `bucket_policy_json` was a raw string with no composition. | Callers had to hand-write the TLS deny and every service grant; nothing checked the JSON; the module could not add guardrails without overwriting the caller. | `modules/bucket-policy`, a pure renderer of typed `statements` plus `deny_insecure_transport`, `deny_unencrypted_object_uploads`, and `deny_incorrect_encryption_key` guardrails. `policy_json_override` remains for a fully caller-owned document. |
| No access logging, CORS, or intelligent tiering. | Common production bucket shapes needed resources outside the module and a second place to look. | `logging`, `cors_rules`, and `intelligent_tiering_configurations` inputs, each optional. |
| `object_lock.retention_mode` and `retention_days` were both required when Object Lock was enabled; `years` was unsupported. | Enabling Object Lock without a default retention, or with a retention in years, was impossible. | `object_lock = { enabled, mode, days | years }`; a default retention is optional and validated (exactly one of days or years). |
| `versioning_enabled` was a boolean. | The provider's third state, `Disabled`, could not be expressed, so a bucket that must never have versioning history was not possible. | `versioning` is `Enabled`, `Suspended`, or `Disabled`, with a `check` that warns whenever it is not `Enabled`. |
| Outputs were `id`, `arn`, and `regional_domain_name`. | Callers needing the hosted zone id, the region, the rendered policy, or the encryption settings had to look them up again. | Eleven flat outputs including `policy`, `lifecycle_rule_ids`, `versioning`, `sse_algorithm`, and `kms_key_arn`. |
| A `terraform_data.input_contract` resource carried the Object Lock precondition. | A resource that exists only to hold a validation is noise in state and in plans. | Cross-variable rules are `lifecycle.precondition` blocks on the resource they guard; single-variable rules are `validation` blocks. |
| No tests, no examples, no upgrade guide. | Behaviour was unpinned and undocumented. | `terraform test` suites for the root and the submodule, five examples validated in CI, `docs/UPGRADE-1.0.md`. |

## Principles and how the module applies them

- **Single responsibility.** `modules/bucket-policy` owns the shape of a bucket
  policy document and nothing else; it creates no resources and declares no
  provider. The root owns the bucket and its configuration resources, one
  resource per S3 API concern (`aws_s3_bucket_versioning`,
  `aws_s3_bucket_logging`, and so on), so each concern changes on its own.
- **Open/closed.** New behaviour is added by declaring data (a lifecycle rule,
  a policy statement, a CORS rule, a tiering configuration), not by editing the
  module. Guardrails are flags, not code.
- **Liskov substitution.** A caller-supplied policy document
  (`policy_json_override`) is a drop-in for the composed one: the same
  `aws_s3_bucket_policy.this[0]` resource, the same `policy` output. A
  caller-supplied KMS key and the AWS-managed key are interchangeable through
  one input.
- **Interface segregation.** Feature groups are optional objects that default
  to `null`, `{}`, or `[]`. A minimal bucket needs only `bucket`.
- **Dependency inversion.** The root depends on identifiers (a bucket name, a
  key ARN, a log bucket name), never on how they were produced. The bucket ARN
  used in the policy is derived from `partition` and `bucket` so the policy is
  known at plan time; the module performs no data-source reads.
- **Clean, deterministic code.** Statements are sorted by `Sid`, conditions
  are grouped by test, lists are sorted, nulls and empties are stripped from
  rendered JSON, `depends_on` is declared only where the S3 API requires
  ordering, and every rule fails at plan time with a message that names the
  input to change.

## Architecture

```text
root (one bucket)
├── aws_s3_bucket.this                                    name, force_destroy, object_lock_enabled, tags (+ Name)
├── aws_s3_bucket_public_access_block.this                all four blocks on, not configurable
├── aws_s3_bucket_ownership_controls.this                 BucketOwnerEnforced by default
├── aws_s3_bucket_versioning.this                         Enabled by default
├── aws_s3_bucket_server_side_encryption_configuration    aws:kms + bucket key by default, AES256 or DSSE on request
├── aws_s3_bucket_object_lock_configuration.this[0]       default retention when object_lock.mode is set
├── aws_s3_bucket_lifecycle_configuration.this[0]         one rule per lifecycle_rules entry
├── aws_s3_bucket_intelligent_tiering_configuration[key]  one per intelligent_tiering_configurations entry
├── aws_s3_bucket_logging.this[0]                         server access logging to a caller bucket
├── aws_s3_bucket_cors_configuration.this[0]              CORS rules
├── modules/bucket-policy                                 pure: statements + guardrails -> JSON (or null)
└── aws_s3_bucket_policy.this[0]                          composed JSON or policy_json_override
```

Data flow: the bucket ARN is computed from `partition` and `bucket` and handed
to `modules/bucket-policy` together with the caller's statements and the
guardrail flags. The submodule returns a JSON document or `null`; the root
creates `aws_s3_bucket_policy.this[0]` only when there is a document, after the
public access block exists (the S3 API rejects policies that grant public
access once the block is on, and the block must win that race). Whether there
is a document is decided from the inputs (the override, the declared
statements, and the guardrail flags), not by inspecting the rendered JSON: the
submodule renders a document exactly when one of those contributes a
statement, and the inputs are known at plan time even when the document is
not, as when a guardrail names a `kms_key_arn` created in the same
configuration and known only after apply. Object Lock and
lifecycle configuration depend on versioning because the API requires it for
Object Lock and for noncurrent-version rules.

### Root interface (summary)

Required: `bucket`.

Optional groups (all default to a safe value):

- Identity: `partition`, `force_destroy`, `tags`.
- Access: `object_ownership`.
- Data protection: `versioning`, `sse_algorithm`, `kms_key_arn`,
  `bucket_key_enabled`, `object_lock`.
- Storage management: `lifecycle_rules`, `intelligent_tiering_configurations`.
- Observability and web: `logging`, `cors_rules`.
- Policy: `bucket_policy_statements`, `deny_insecure_transport`,
  `deny_unencrypted_object_uploads`, `deny_incorrect_encryption_key`,
  `policy_json_override`.

Outputs expose every identifier a caller may need to wire IAM, DNS, logging,
replication, or notifications: `id`, `arn`, `bucket_domain_name`,
`bucket_regional_domain_name`, `hosted_zone_id`, `region`, the rendered
`policy`, `lifecycle_rule_ids`, `versioning`, `sse_algorithm`, and
`kms_key_arn`.

### Lifecycle rules

- The public access block is not an input. A bucket that must serve public
  objects is a different product (CloudFront with origin access control in front
  of a private bucket is the supported shape) and is out of scope.
- `versioning = "Disabled"` is accepted only on a bucket that has never been
  versioned; the S3 API rejects it afterwards. Use `Suspended` on an existing
  bucket.
- Object Lock can only be enabled when the bucket is created and requires
  versioning `Enabled`; the module enforces the second rule with a precondition
  and documents the first.
- `force_destroy = true` lets Terraform delete a non-empty bucket. A `check`
  warns on every plan while it is set.
- `policy_json_override` replaces the composed policy entirely and is mutually
  exclusive with `bucket_policy_statements` and the three guardrail flags, so a
  caller who takes over the policy does so knowingly.

## Security defaults

- All four public access blocks on; ownership `BucketOwnerEnforced` (ACLs
  disabled); a `check` warns when ownership is relaxed.
- Versioning `Enabled`; a `check` warns when it is not.
- Default encryption SSE-KMS with an S3 Bucket Key. `kms_key_arn` selects a
  customer managed key; without it the AWS-managed `aws/s3` key is used.
- Bucket policy statement `DenyInsecureTransport`: `Deny s3:*` for every
  principal on the bucket and its objects when `aws:SecureTransport` is false.
- Opt-in upload guardrails: `DenyUnencryptedObjectUploads` (the
  `x-amz-server-side-encryption` header must name the bucket's algorithm) and
  `DenyIncorrectEncryptionKey` (the KMS key header must name `kms_key_arn`).
- Declared statements are typed: `Sid` is validated, principals are typed by
  kind, resources default to the bucket and its objects, conditions are
  grouped by test. Reserved guardrail Sids cannot be shadowed. A repeated
  condition test and variable pair is rejected by name rather than by
  Terraform's duplicate-key error.
- An `Allow` for the wildcard principal must carry a condition. The public
  access block is always on, so S3 would reject the unconditioned form at
  apply; rejecting it at plan matches `aws.modules.dynamodb` and
  `aws.modules.ksm`. Whether a conditioned wildcard `Allow` counts as public
  is still decided by S3 at apply (it depends on the condition key and value).
- The rendered document must fit the 20 KB S3 bucket policy limit; a
  precondition on the submodule's `json` output fails the plan otherwise.
- Not guarded: a `Deny` for the wildcard principal is accepted without a
  condition, because scoped denies for every principal are a legitimate
  control. An unconditioned `Deny s3:*` (or one whose condition every request
  satisfies) also denies the bucket owner and the Terraform role, so the next
  apply cannot remove it and only the account root user can recover the
  bucket. The READMEs call this out next to the statement documentation.
- The module never adds an ACL, a public policy, or a notification, and never
  reads from the account at plan time.

## Testing strategy

- Contract tests use `mock_provider` with `command = plan`; no credentials.
- Root `tests/` cover: secure defaults, every variable validation and
  precondition via `expect_failures`, every feature group, the policy
  composition and the `policy_json_override` substitution, when a policy
  resource is planned at all (every boundary of the contributing inputs, and
  a KMS key created in the same configuration through the
  `tests/setup/key-and-bucket` fixture, whose ARN is unknown at plan), and
  each advisory `check`.
- `modules/bucket-policy/tests/` exercises the renderer without any provider:
  each guardrail, statement merging and ordering, principal and Sid
  validation, condition grouping and uniqueness, the wildcard-Allow condition
  rule, the 20 KB size limit, the empty document, and the key requirement.
- Every example is initialised and validated in CI; examples are the
  documentation's executable form.
- Static policy: `tflint` with the AWS ruleset, Checkov, Trivy; generated docs
  are checked for drift.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0` (the consuming platform pins 1.7.5).
- AWS provider `>= 6.35.0, < 7.0.0`.
- Out of scope in v1 and planned as optional inputs that will not break this
  interface: replication, event notifications, transfer acceleration, request
  payment, MFA delete, inventory and analytics configurations, and website
  hosting. Public buckets and ACL-based grants are not planned.

## Migration

`docs/UPGRADE-1.0.md` maps every v0.1.x input to its v1 equivalent, lists the
settings that preserve the existing bucket configuration, and explains that no
`moved` blocks are required because every resource address is unchanged; only
`terraform_data.input_contract` is destroyed.
