# Compliance archive

A write-once bucket for records that must not change: Object Lock in
`COMPLIANCE` mode with a default retention in years, SSE-KMS under a customer
managed key, both upload guardrails so no object can be written without naming
that key, and a lifecycle rule that moves records to `GLACIER_IR` after 90 days
and to `DEEP_ARCHIVE` after a year, with noncurrent versions archived after 30
days. Versioning is `Enabled` (Object Lock requires it) and `force_destroy`
stays `false`.

Read this before applying: `COMPLIANCE` retention cannot be shortened or removed
by anyone, including the account root user, until it expires. Object versions
written to this bucket exist for at least `retention_years`, and the bucket
cannot be deleted while any locked version remains. Object Lock itself can only
be enabled when the bucket is created; it cannot be added to, or removed from,
an existing bucket through this module.

## Run

```sh
terraform init
terraform plan \
  -var bucket=records-archive-123456789012 \
  -var kms_key_arn=arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111
```

`retention_years` defaults to 7; override it to match your retention policy.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_archive"></a> [archive](#module\_archive) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Globally unique bucket name. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key ARN every upload must be encrypted with. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the archive bucket is created in. | `string` | `"us-east-1"` | no |
| <a name="input_retention_years"></a> [retention\_years](#input\_retention\_years) | COMPLIANCE default retention applied to every new object version, in years. | `number` | `7` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. | `map(string)` | <pre>{<br/>  "DataClassification": "regulated"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the archive bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the archive bucket. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | Key every object is encrypted with. |
| <a name="output_policy"></a> [policy](#output\_policy) | Bucket policy: transport, encryption-header, and key guardrails. |
<!-- END_TF_DOCS -->
