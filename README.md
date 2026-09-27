# aws.modules.s3

Provisions **one** private Amazon S3 bucket per module call together with the configuration a bucket should never exist without: a public access block, ownership controls, versioning, default server-side encryption, and a bucket policy that refuses unencrypted transport. Every further capability — Object Lock, lifecycle rules, Intelligent-Tiering, server access logging, CORS, additional policy statements, and upload guardrails — is a typed, optional input that is off until declared. The bucket policy is rendered by a pure submodule, `modules/bucket-policy`, that callers can use on its own or replace entirely with a caller-supplied document. Requires Terraform >= 1.7 and the AWS provider >= 6.35, < 7.

## Why this module

What you get from `bucket` alone, without setting anything else:

- No public access. All four public access block settings are always on and are not configurable; a bucket that must serve public objects is a different product (CloudFront with origin access control in front of a private bucket) and out of scope.
- `BucketOwnerEnforced` object ownership by default, so ACLs are disabled; the `ownership_not_enforced` check warns on every plan when it is relaxed.
- Versioning `Enabled` by default, expressed as one of three real API states (`Enabled`, `Suspended`, `Disabled`) instead of a boolean; the `versioning_not_enabled` check warns otherwise.
- Default encryption SSE-KMS with an S3 Bucket Key. `kms_key_arn` selects a customer managed key; without it, the AWS managed `aws/s3` key is used. `AES256` and `aws:kms:dsse` are one input away.
- A bucket policy statement `DenyInsecureTransport`: deny every S3 action for every principal when the request does not use TLS. Attached only after the public access block exists, so a policy can never be evaluated before the block is in place.
- Opt-in upload guardrails: `deny_unencrypted_object_uploads` (the upload must carry the bucket's encryption header) and `deny_incorrect_encryption_key` (the upload must name the bucket's KMS key), both rendered by `modules/bucket-policy` alongside any statements you declare.
- Every other capability off until declared: Object Lock, lifecycle rules, Intelligent-Tiering, server access logging, CORS, and additional policy statements are typed optional inputs with no effect at their default.
- `force_destroy = true` lets `terraform destroy` delete a non-empty bucket; the `force_destroy_enabled` check warns on every plan while it is set.
- No data-source reads. The bucket ARN used in the policy is derived from `partition` and `bucket`, so the policy is known at plan time and the module never looks anything up in the account.
- Stable naming and tags. The module adds a `Name` tag equal to `bucket` unless the caller sets one; caller tags are never overridden.
- Plan-time validation of every input: the general purpose bucket naming rules, the encryption and Object Lock cross-input rules, every lifecycle rule field, Intelligent-Tiering tier and day ranges, logging target and key-format combinations, CORS bounds, and the bucket policy statement shape.

## Quick start

```hcl
module "bucket" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git?ref=<commit-sha>" # v1.0.0

  bucket = "orders-data-123456789012"
  tags   = { Environment = "prod", Owner = "orders" }
}
```

This creates a private bucket `orders-data-123456789012` with all four public access blocks on, `BucketOwnerEnforced` ownership, versioning `Enabled`, default encryption SSE-KMS under the AWS managed `aws/s3` key with an S3 Bucket Key, and one bucket policy statement, `DenyInsecureTransport`, denying every action for every principal when `aws:SecureTransport` is false. No lifecycle rule, Object Lock configuration, logging, CORS rule, or additional policy statement exists.

## Architecture

```text
root (one bucket)
├── aws_s3_bucket.this                                    name, force_destroy, object_lock_enabled, tags (+ Name)
├── aws_s3_bucket_public_access_block.this                all four blocks on, not configurable
├── aws_s3_bucket_ownership_controls.this                 BucketOwnerEnforced by default
├── aws_s3_bucket_versioning.this                         Enabled by default
├── aws_s3_bucket_server_side_encryption_configuration    aws:kms + bucket key by default, AES256 or DSSE on request
├── aws_s3_bucket_object_lock_configuration.this[0]        default retention when object_lock.mode is set
├── aws_s3_bucket_lifecycle_configuration.this[0]          one rule per lifecycle_rules entry
├── aws_s3_bucket_intelligent_tiering_configuration[key]   one per intelligent_tiering_configurations entry
├── aws_s3_bucket_logging.this[0]                          server access logging to a caller bucket
├── aws_s3_bucket_cors_configuration.this[0]               CORS rules
├── modules/bucket-policy                                  pure: statements + guardrails -> JSON (or null)
└── aws_s3_bucket_policy.this[0]                           composed JSON or policy_json_override
```

The bucket ARN is computed from `partition` and `bucket` and handed to `modules/bucket-policy` together with the caller's statements and the guardrail flags. The submodule returns a JSON document or `null`; the root creates `aws_s3_bucket_policy.this[0]` only when there is a document, after the public access block exists. Object Lock and lifecycle configuration depend on versioning because the API requires it for both.

| Concern | Managed by default | Bring your own |
| --- | --- | --- |
| Encryption key | The AWS managed `aws/s3` key. | `kms_key_arn` for a customer managed key, with `sse_algorithm` selecting `aws:kms` (default) or `aws:kms:dsse`; `AES256` uses no key and disables the Bucket Key. |
| Bucket policy | `DenyInsecureTransport` only. | `bucket_policy_statements` for typed statements, the two upload guardrails for additional deny rules, or `policy_json_override` to replace the whole composition with a document you own. |
| Server access logging | None. | `logging = { target_bucket, target_prefix, target_object_key_format }` targeting a bucket you manage (see `examples/access-logging` for the policy the destination needs). |
| Object Lock | Off. | `object_lock = { enabled = true }` at bucket creation, optionally with `mode` and `days` or `years` for a default retention; requires `versioning = "Enabled"`. |
| Storage management | None. | `lifecycle_rules` for expirations, transitions, and noncurrent-version actions; `intelligent_tiering_configurations` for archive tiers on objects already in `INTELLIGENT_TIERING`. |

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | The smallest call: a name and tags, every other decision left at its secure default. |
| [`examples/complete`](examples/complete) | Every feature group together: Object Lock with a default retention, a four-rule lifecycle configuration feeding Intelligent-Tiering, server access logging, CORS, and both upload guardrails alongside declared read statements. |
| [`examples/compliance-archive`](examples/compliance-archive) | A write-once archive: Object Lock in `COMPLIANCE` mode with a multi-year default retention, mandatory encryption under a customer managed key, and lifecycle transitions to cold storage. |
| [`examples/access-logging`](examples/access-logging) | Two module calls: a log destination bucket with the `S3ServerAccessLogsPolicy` statement AWS documents, and a data bucket whose `logging` input targets it with date-partitioned keys. |
| [`examples/multiple-buckets`](examples/multiple-buckets) | One module call is one bucket; a fleet is a `for_each` over the module block, keeping each bucket's plan, validation, and lifecycle independent. |

## Security model

- All four public access block settings are always on and are not an input; ownership defaults to `BucketOwnerEnforced` with the `ownership_not_enforced` check warning otherwise.
- Versioning defaults to `Enabled`; `Disabled` is accepted only on a bucket that has never been versioned (S3 rejects it afterwards), and the `versioning_not_enabled` check warns on anything but `Enabled`.
- Default encryption is SSE-KMS with an S3 Bucket Key. `kms_key_arn` must be a key ARN, not an alias or bare key ID, because the upload-guardrail condition compares the ARN; it is rejected with `AES256` and required by `deny_incorrect_encryption_key`.
- `DenyInsecureTransport` denies `s3:*` for every principal on the bucket and its objects when `aws:SecureTransport` is false. It is on by default and is the CIS and AWS Foundational Security Best Practices control for S3 buckets.
- `deny_unencrypted_object_uploads` denies `s3:PutObject` unless the upload's `x-amz-server-side-encryption` header names `sse_algorithm`; relying on the bucket's default encryption without sending the header is denied too.
- `deny_incorrect_encryption_key` denies `s3:PutObject` unless the upload's KMS key header names `kms_key_arn`.
- Declared statements (`bucket_policy_statements`) are typed and validated at plan time: Sid is alphanumeric and cannot shadow a reserved guardrail Sid, principals are named by type with at least one identifier, resources default to the bucket and its objects and must lie within it, and conditions are grouped by test in the rendered document.
- `policy_json_override` replaces the composed policy entirely; a resource precondition rejects it alongside declared statements or an enabled guardrail, so taking over the policy is an explicit, single choice.
- The module never adds an ACL, a public policy, or a notification, and never reads from the account at plan time — the bucket ARN used throughout is derived from `partition` and `bucket`.

## Lifecycle notes

- `versioning = "Disabled"` is accepted only on a bucket that has never been versioned; use `"Suspended"` on an existing bucket, or S3 rejects the change at apply time.
- Object Lock can only be enabled when the bucket is created, and requires `versioning = "Enabled"`; the module enforces the versioning rule with a `lifecycle.precondition` on `aws_s3_bucket.this` and documents the creation-time rule, since Terraform cannot express it.
- `object_lock.mode` (`GOVERNANCE` or `COMPLIANCE`) with exactly one of `days` or `years` adds a default retention; omitting `mode` enables Object Lock with no default retention.
- A lifecycle rule's filter takes a single criterion directly (a prefix, one tag, or one size bound) and needs an `and` block for two or more, which includes any filter with more than one tag; the module computes which shape to render, so a caller only declares the criteria.
- `force_destroy = true` lets `terraform destroy` delete every object and object version in the bucket; the `force_destroy_enabled` check warns on every plan while it is set.
- `intelligent_tiering_configurations` acts only on objects already stored in the `INTELLIGENT_TIERING` storage class — typically arrived at through a `lifecycle_rules` transition, as in `examples/complete`.
- `aws_s3_bucket_policy.this[0]` is created only when there is a document to attach (any guardrail enabled, any statement declared, or an override supplied); with everything off, `policy` is `null` and no policy resource exists.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/` for the root, `modules/bucket-policy/tests/` for the submodule, run by `make test` and by CI) use `mock_provider`: no credentials, nothing created. `tests/defaults.tftest.hcl` asserts the secure defaults; `tests/features.tftest.hcl` asserts every optional feature group's rendering; `tests/policy.tftest.hcl` asserts the guardrail-and-statement composition and the `policy_json_override` substitution; `tests/validation.tftest.hcl` covers every precondition and validation through `expect_failures`. `modules/bucket-policy/tests/bucket_policy.tftest.hcl` exercises the renderer alone, with no provider at all.
- **Integration suites** (`tests/integration/`, run by `make integration-smoke` or the dispatch-only `integration` workflow) apply the module for real in **your** account with **your** credentials and region from the environment, then destroy everything. `smoke` creates a bucket with versioning, SSE-KMS under the AWS managed key, a lifecycle rule, and the deny-insecure-transport policy, with `force_destroy = true` so teardown succeeds; it costs nothing beyond incidental storage. The owner lane runs the same suite from GitHub Actions through the protected `integration` environment, which holds the OIDC role and region; see [`tests/integration`](tests/integration) for permissions and the environment contract.

## Design principles

- **Single responsibility.** `modules/bucket-policy` owns the shape of a bucket policy document and nothing else; it creates no resources and declares no provider. The root owns the bucket and its configuration resources, one resource per S3 API concern, so each concern changes on its own.
- **Open/closed.** New behaviour is added by declaring data — a lifecycle rule, a policy statement, a CORS rule, a tiering configuration — not by editing the module. Guardrails are flags, not code.
- **Liskov substitution.** A caller-supplied policy document (`policy_json_override`) is a drop-in for the composed one: the same `aws_s3_bucket_policy.this[0]` resource, the same `policy` output. A caller-supplied KMS key and the AWS managed key are interchangeable through one input.
- **Interface segregation.** Feature groups are optional objects that default to `null`, `{}`, or `[]`. A minimal bucket needs only `bucket`.
- **Dependency inversion.** The root depends on identifiers — a bucket name, a key ARN, a log bucket name — never on how they were produced. The bucket ARN used in the policy is derived from inputs, so the module performs no data-source reads.

The full rationale, including why the v0.1.x design was replaced, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- Out of scope in v1 and planned as optional inputs that will not break this interface: replication, event notifications, transfer acceleration, request payment, MFA delete, inventory and analytics configurations, and website hosting.
- Public buckets and ACL-based grants are not planned; a bucket that must serve public objects is a different product (CloudFront with origin access control) and out of scope for this module.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the major version, new optional inputs and outputs bump the minor version, fixes bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment, so the source cannot move under you:

```hcl
module "bucket" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git?ref=<commit-sha>" # v1.0.0
}

module "policy" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git//modules/bucket-policy?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only from a GitHub-verified, signed, annotated semantic-version tag that points at the merged `main` revision; lightweight or unsigned tags are rejected before anything is published. With a GitHub-associated GPG or SSH signing key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag points at the revision it checked out, and a maintenance release for an older line is cut from that line's commit.

Upgrading from 0.x: read [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) for the input and output mapping, the preserved resource addresses, and a worked example. All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the release process are described in [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bucket_policy"></a> [bucket\_policy](#module\_bucket\_policy) | ./modules/bucket-policy | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_intelligent_tiering_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Name of the bucket, globally unique. 3-63 lowercase letters, digits, dots, and hyphens, starting and ending with a letter or digit, following the general purpose bucket naming rules (no adjacent dots, not shaped like an IP address, no reserved prefix or suffix). Also the Name tag. | `string` | n/a | yes |
| <a name="input_bucket_key_enabled"></a> [bucket\_key\_enabled](#input\_bucket\_key\_enabled) | Use an S3 Bucket Key so SSE-KMS objects share data keys and KMS requests drop by up to 99 percent. Only meaningful for aws:kms and aws:kms:dsse; rendered as false with AES256. | `bool` | `true` | no |
| <a name="input_bucket_policy_statements"></a> [bucket\_policy\_statements](#input\_bucket\_policy\_statements) | Bucket policy statements keyed by alphanumeric Sid, merged with the enabled guardrails and rendered by modules/bucket-policy. Each names principals by type (AWS, Service, Federated, CanonicalUser) or sets principal\_all, lists actions, optionally restricts resources to the bucket or paths under it (default: the bucket and its objects), and may add conditions. | <pre>map(object({<br/>    effect        = optional(string, "Allow")<br/>    principals    = optional(map(set(string)), {})<br/>    principal_all = optional(bool, false)<br/>    actions       = set(string)<br/>    resources     = optional(set(string))<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = set(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_cors_rules"></a> [cors\_rules](#input\_cors\_rules) | CORS rules, at most 100. Each names the allowed origins and methods (GET, PUT, HEAD, POST, DELETE), optional allowed request headers and exposed response headers, an optional id, and an optional max\_age\_seconds for preflight caching. Empty disables CORS. | <pre>list(object({<br/>    id              = optional(string)<br/>    allowed_headers = optional(set(string), [])<br/>    allowed_methods = set(string)<br/>    allowed_origins = set(string)<br/>    expose_headers  = optional(set(string), [])<br/>    max_age_seconds = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_deny_incorrect_encryption_key"></a> [deny\_incorrect\_encryption\_key](#input\_deny\_incorrect\_encryption\_key) | Add the DenyIncorrectEncryptionKey statement: deny s3:PutObject unless the x-amz-server-side-encryption-aws-kms-key-id header names kms\_key\_arn. Requires kms\_key\_arn. | `bool` | `false` | no |
| <a name="input_deny_insecure_transport"></a> [deny\_insecure\_transport](#input\_deny\_insecure\_transport) | Add the DenyInsecureTransport statement: deny every S3 action on the bucket and its objects when the request does not use TLS. | `bool` | `true` | no |
| <a name="input_deny_unencrypted_object_uploads"></a> [deny\_unencrypted\_object\_uploads](#input\_deny\_unencrypted\_object\_uploads) | Add the DenyUnencryptedObjectUploads statement: deny s3:PutObject unless the x-amz-server-side-encryption header names sse\_algorithm. Clients must send the header; relying on default encryption is denied too. | `bool` | `false` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Let terraform destroy delete the bucket together with every object and object version in it. Keep false for data you cannot recreate; the force\_destroy\_enabled check warns on every plan while it is true. | `bool` | `false` | no |
| <a name="input_intelligent_tiering_configurations"></a> [intelligent\_tiering\_configurations](#input\_intelligent\_tiering\_configurations) | Intelligent-Tiering archive configurations keyed by configuration name: status (Enabled or Disabled), an optional prefix and tags filter, and one tiering per archive tier (ARCHIVE\_ACCESS after 90-730 days, DEEP\_ARCHIVE\_ACCESS after 180-730 days). Objects must be stored in the INTELLIGENT\_TIERING class, for example through a lifecycle transition, for a configuration to act. | <pre>map(object({<br/>    status = optional(string, "Enabled")<br/>    filter = optional(object({<br/>      prefix = optional(string)<br/>      tags   = optional(map(string), {})<br/>    }))<br/>    tierings = list(object({<br/>      access_tier = string<br/>      days        = number<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the customer managed KMS key for aws:kms and aws:kms:dsse (arn:<partition>:kms:<region>:<account>:key/<id>). Null uses the AWS managed key aws/s3. Not allowed with AES256. Required by deny\_incorrect\_encryption\_key. | `string` | `null` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Lifecycle rules keyed by rule id. Each rule needs at least one action: expiration (exactly one of days, date, or expired\_object\_delete\_marker), transitions (exactly one of days or date each), noncurrent\_version\_transitions, noncurrent\_version\_expiration, or abort\_incomplete\_multipart\_upload\_days. An omitted filter applies the rule to every object; prefix, tags, and object size bounds combine with AND. Dates are RFC 3339 timestamps at midnight UTC (YYYY-MM-DDT00:00:00Z). | <pre>map(object({<br/>    enabled = optional(bool, true)<br/>    filter = optional(object({<br/>      prefix                   = optional(string)<br/>      tags                     = optional(map(string), {})<br/>      object_size_greater_than = optional(number)<br/>      object_size_less_than    = optional(number)<br/>    }))<br/>    expiration = optional(object({<br/>      days                         = optional(number)<br/>      date                         = optional(string)<br/>      expired_object_delete_marker = optional(bool)<br/>    }))<br/>    transitions = optional(list(object({<br/>      days          = optional(number)<br/>      date          = optional(string)<br/>      storage_class = string<br/>    })), [])<br/>    noncurrent_version_transitions = optional(list(object({<br/>      noncurrent_days           = number<br/>      newer_noncurrent_versions = optional(number)<br/>      storage_class             = string<br/>    })), [])<br/>    noncurrent_version_expiration = optional(object({<br/>      noncurrent_days           = number<br/>      newer_noncurrent_versions = optional(number)<br/>    }))<br/>    abort_incomplete_multipart_upload_days = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_logging"></a> [logging](#input\_logging) | Server access logging: the destination bucket (it must allow logging.s3.amazonaws.com to put objects; see examples/access-logging), an optional key prefix, and an optional target object key format (partitioned by EventTime or DeliveryTime, or simple). Null disables logging. | <pre>object({<br/>    target_bucket = string<br/>    target_prefix = optional(string, "")<br/>    target_object_key_format = optional(object({<br/>      partitioned = optional(object({<br/>        partition_date_source = optional(string, "EventTime")<br/>      }))<br/>      simple = optional(bool, false)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_object_lock"></a> [object\_lock](#input\_object\_lock) | Object Lock. enabled can only be set when the bucket is created and requires versioning = Enabled. mode (GOVERNANCE or COMPLIANCE) with exactly one of days or years adds a default retention period for new objects; omit mode to enable Object Lock without a default retention. | <pre>object({<br/>    enabled = optional(bool, false)<br/>    mode    = optional(string)<br/>    days    = optional(number)<br/>    years   = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_object_ownership"></a> [object\_ownership](#input\_object\_ownership) | Object Ownership setting: BucketOwnerEnforced (ACLs disabled, the default), BucketOwnerPreferred, or ObjectWriter. The other two values re-enable ACLs and trigger the ownership\_not\_enforced check on every plan. | `string` | `"BucketOwnerEnforced"` | no |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition the bucket lives in: aws, aws-cn, or aws-us-gov. The bucket ARN used in the policy is derived from it at plan time, so the module performs no lookups. | `string` | `"aws"` | no |
| <a name="input_policy_json_override"></a> [policy\_json\_override](#input\_policy\_json\_override) | Complete bucket policy document that replaces the composed one. When set, bucket\_policy\_statements must be empty and deny\_insecure\_transport, deny\_unencrypted\_object\_uploads, and deny\_incorrect\_encryption\_key must be false, so taking over the policy is an explicit choice. | `string` | `null` | no |
| <a name="input_sse_algorithm"></a> [sse\_algorithm](#input\_sse\_algorithm) | Default server-side encryption for new objects: aws:kms (SSE-KMS, default), AES256 (SSE-S3), or aws:kms:dsse (dual-layer SSE-KMS). Also the algorithm the deny\_unencrypted\_object\_uploads guardrail requires in upload headers. | `string` | `"aws:kms"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. The module adds a Name tag equal to the bucket name unless you set one; caller tags are never overridden. | `map(string)` | `{}` | no |
| <a name="input_versioning"></a> [versioning](#input\_versioning) | Versioning state: Enabled (default), Suspended, or Disabled. S3 accepts Disabled only on a bucket that has never been versioned; use Suspended on an existing bucket. Object Lock requires Enabled. Anything but Enabled triggers the versioning\_not\_enabled check. | `string` | `"Enabled"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the bucket. |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Global domain name of the bucket (<bucket>.s3.amazonaws.com). |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the bucket (<bucket>.s3.<region>.amazonaws.com), the value to use for CloudFront origins and DNS aliases. |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id) | Route 53 hosted zone ID of the bucket's region, for alias records. |
| <a name="output_id"></a> [id](#output\_id) | Name of the bucket. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | Customer managed KMS key ARN used for default encryption, or null when the AWS managed key (or SSE-S3) is used. |
| <a name="output_lifecycle_rule_ids"></a> [lifecycle\_rule\_ids](#output\_lifecycle\_rule\_ids) | Ids of the declared lifecycle rules, sorted. |
| <a name="output_policy"></a> [policy](#output\_policy) | Bucket policy document attached to the bucket (composed or policy\_json\_override), or null when no policy is attached. |
| <a name="output_region"></a> [region](#output\_region) | Region the bucket resides in. |
| <a name="output_sse_algorithm"></a> [sse\_algorithm](#output\_sse\_algorithm) | Default server-side encryption algorithm: aws:kms, AES256, or aws:kms:dsse. |
| <a name="output_versioning"></a> [versioning](#output\_versioning) | Versioning state applied to the bucket: Enabled, Suspended, or Disabled. |
<!-- END_TF_DOCS -->
