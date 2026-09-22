# aws.modules.s3

Versioned Terraform module for a private, customer-KMS-encrypted S3 bucket.
It applies all four public-access blocks, BucketOwnerEnforced ownership, bucket
keys, versioning, optional Object Lock at creation time, optional lifecycle
rules, and an optional caller-owned bucket policy.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.input_contract](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Globally unique S3 bucket name. | `string` | n/a | yes |
| <a name="input_bucket_policy_json"></a> [bucket\_policy\_json](#input\_bucket\_policy\_json) | Optional complete bucket-policy JSON. | `string` | `null` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether non-empty bucket deletion is permitted. Keep false for production data. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer-managed KMS key ARN for default bucket encryption. | `string` | n/a | yes |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Lifecycle rules keyed by stable logical name. | <pre>map(object({<br/>    noncurrent_version_expiration_days = optional(number)<br/>    abort_incomplete_multipart_days    = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_object_lock"></a> [object\_lock](#input\_object\_lock) | Optional object-lock configuration. Object Lock can only be enabled when a bucket is first created. | <pre>object({<br/>    enabled        = bool<br/>    retention_mode = optional(string)<br/>    retention_days = optional(number)<br/>  })</pre> | <pre>{<br/>  "enabled": false<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the S3 bucket. | `map(string)` | `{}` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Whether S3 versioning is enabled. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the S3 bucket. |
| <a name="output_id"></a> [id](#output\_id) | Name of the S3 bucket. |
| <a name="output_regional_domain_name"></a> [regional\_domain\_name](#output\_regional\_domain\_name) | Regional DNS name of the S3 bucket. |
<!-- END_TF_DOCS -->