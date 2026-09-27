# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

## [1.0.0] - 2026-09-25

Breaking release. One module call still provisions one private bucket. [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md) maps every 0.1.x input and output to its replacement; every resource address is unchanged, so no `moved` blocks are needed.

### Added

- `sse_algorithm` (`aws:kms` default, `AES256`, `aws:kms:dsse`) with an optional `kms_key_arn`; without a key, default encryption uses the AWS managed `aws/s3` key.
- `versioning` as a three-state string (`Enabled`, `Suspended`, `Disabled`) in place of a boolean, so a never-versioned bucket can stay that way.
- A typed `lifecycle_rules` map keyed by rule id: a filter (prefix, tags, object size bounds, combined with `and` when more than one criterion applies), expiration (days, date, or delete-marker), transitions and noncurrent-version transitions, noncurrent-version expiration, and `abort_incomplete_multipart_upload_days`, each validated at plan time.
- `intelligent_tiering_configurations`, keyed by configuration name, with a filter and one or two tierings.
- `logging` for server access logging to a caller-owned bucket, with partitioned or simple target key formats.
- `cors_rules`, up to 100, each with origins, methods, headers, and max age.
- `object_lock` as `{ enabled, mode, days | years }`: Object Lock can be enabled without a default retention, and a retention can be declared in years as well as days.
- `modules/bucket-policy`, a pure renderer with no resources and no provider: typed `bucket_policy_statements` keyed by Sid, plus the guardrails `deny_insecure_transport` (default true), `deny_unencrypted_object_uploads`, and `deny_incorrect_encryption_key`. It sorts statements by Sid, sorts every list, groups conditions by test, and rejects a resource outside the bucket at plan time.
- `policy_json_override` for a fully caller-owned policy document, mutually exclusive with the composed policy by a resource precondition.
- `partition`, `object_ownership`, `bucket_key_enabled`, and outputs `bucket_domain_name`, `hosted_zone_id`, `region`, `policy`, `lifecycle_rule_ids`, `versioning`, `sse_algorithm`, and `kms_key_arn`.
- Advisory `check` blocks that warn without blocking: `force_destroy_enabled`, `versioning_not_enabled`, `ownership_not_enforced`.
- Plan-time validation of every input: the general purpose bucket naming rules (length, character set, adjacent dots, IP-address shape, reserved prefixes and suffixes), the encryption and Object Lock cross-input rules, every lifecycle rule field (storage classes, day and date bounds, filter combinations), Intelligent-Tiering tier and day ranges, logging target and key-format combinations, CORS methods and bounds, and the bucket policy statement shape (Sid, principals, actions, resources, conditions).
- Examples `minimal`, `complete`, `compliance-archive`, `access-logging`, and `multiple-buckets`, validated in CI.
- `modules/bucket-policy/tests/` covering the renderer alone (no provider), and root `tests/` covering secure defaults, every feature group, the policy composition and override, and every validation and check through `expect_failures`.
- A credential-driven integration suite `smoke` in `tests/integration/`, a `make integration-smoke` target, a dispatch-only `integration` workflow that assumes a role through GitHub OIDC from the protected `integration` environment, and the IAM trust and permissions documents the role needs.
- `docs/DESIGN.md`, `docs/UPGRADE-1.0.md`, the `modules/bucket-policy` README, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

### Changed

- **Breaking:** `bucket_name` is renamed `bucket`.
- **Breaking:** `kms_key_arn` is optional; a bucket that omits it now encrypts under the AWS managed key instead of failing validation.
- **Breaking:** `versioning_enabled` (bool) is replaced by `versioning` (string): `true` becomes `"Enabled"` (the default), `false` becomes `"Suspended"`.
- **Breaking:** `object_lock.retention_mode` and `retention_days` are renamed `mode` and `days`; a retention is optional even when `enabled = true`.
- **Breaking:** `lifecycle_rules[*].noncurrent_version_expiration_days` and `abort_incomplete_multipart_days` are replaced by the typed shape (`noncurrent_version_expiration.noncurrent_days`, `abort_incomplete_multipart_upload_days`); an unchanged rule id with equivalent settings produces no diff.
- **Breaking:** `bucket_policy_json` is renamed `policy_json_override` and must be paired with `deny_insecure_transport = false`; a bucket policy is attached by default (`DenyInsecureTransport`) where 0.1.x attached none unless `bucket_policy_json` was set.
- **Breaking:** output `regional_domain_name` is renamed `bucket_regional_domain_name`.
- The module adds a `Name` tag equal to `bucket` unless the caller sets one; caller tags are never overridden.
- The AWS provider constraint is `>= 6.35.0, < 7.0.0` (was `>= 6.0, < 7.0`).
- CI runs the shared `terraform-quality` workflow over the root, `modules/bucket-policy`, and every example, with a docs drift check.

### Removed

- **Breaking:** `terraform_data.input_contract`. Its Object Lock precondition moved to a `lifecycle.precondition` on `aws_s3_bucket.this`; the resource itself is destroyed on upgrade and nothing in AWS is touched.
- **Breaking:** the top-level inputs `bucket_name`, `versioning_enabled`, `object_lock.retention_mode`, `object_lock.retention_days`, `bucket_policy_json` (see Changed).

### Fixed

- The public access block is created unconditionally and every policy attachment depends on it, so a policy can never be evaluated before the block exists.
- Lifecycle noncurrent-version actions and the Object Lock default retention now explicitly depend on `aws_s3_bucket_versioning.this`, so the S3 API never rejects them for missing versioning on the first apply.

## [0.1.2] - 2026-09-22

### Changed

- The committed provider lock file carries checksums for the platforms CI and contributors use.
- The quality workflow validates modules that declare provider configuration aliases.

## [0.1.1] - 2026-09-22

### Added

- Generated module reference (inputs and outputs tables) in the README.

## [0.1.0] - 2026-09-22

### Added

- Versioned S3 bucket module: a private bucket with a required customer managed KMS key, a versioning boolean, a two-field lifecycle rule shape, an Object Lock block requiring a retention in days, and an optional raw bucket policy document.

[Unreleased]: https://github.com/hatan4ik/aws.modules.s3/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.s3/compare/v0.1.2...v1.0.0
[0.1.2]: https://github.com/hatan4ik/aws.modules.s3/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/hatan4ik/aws.modules.s3/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/hatan4ik/aws.modules.s3/releases/tag/v0.1.0
