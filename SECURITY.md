# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan or rendered policy, and the impact you see. Redact account IDs, bucket names, and key ARNs.

## What counts

- A module default that weakens security: any of the four public access block settings off, ACLs enabled without `object_ownership` being changed deliberately, versioning not `Enabled` without the advisory check firing, default encryption missing or using an algorithm other than the one declared, or a bucket policy composed without `DenyInsecureTransport` when `deny_insecure_transport` was left at its default.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider, including a `policy_json_override` combined with declared statements or an enabled guardrail, a lifecycle rule accepted with two filter forms in the same criterion, or an Object Lock retention accepted without `versioning = "Enabled"`.
- A bucket policy rendering bug: a statement whose resources are not confined to the bucket and its objects, a guardrail Sid a caller could shadow with a declared statement, a condition or principal that renders differently from what the typed input declared, or a document that changes between two plans with no input change (nondeterministic ordering).
- KMS over-permission: `deny_incorrect_encryption_key` accepted without `kms_key_arn`, or a rendered condition that would admit an upload encrypted under a key other than the one declared.
- A caller-supplied KMS key, log destination bucket, or policy document that the module modifies instead of using as-is.
- A dependency ordering bug that lets a bucket policy or a public-facing configuration apply before the public access block exists.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a `bucket_policy_statements` entry you declared with a broad principal, or `deny_insecure_transport = false` you set deliberately) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: all four public access blocks always on and not configurable; `BucketOwnerEnforced` ownership by default with ACLs disabled; versioning `Enabled` by default; default encryption SSE-KMS with an S3 Bucket Key; a bucket policy that denies every action for every principal when the request does not use TLS, attached only after the public access block exists; upload guardrails available on request that deny an upload missing the declared encryption header or naming the wrong KMS key; a bucket policy renderer (`modules/bucket-policy`) that has no resources, no provider, and rejects any statement resource outside the bucket at plan time; no data-source reads; and only a `Name` tag added. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security defaults](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
