# Complete bucket

Every feature group of `aws.modules.s3` in one call: SSE-KMS with a customer
managed key and an S3 Bucket Key; Object Lock with a 30-day `GOVERNANCE`
default retention; four lifecycle rules showing an unfiltered rule, a prefix
filter with transitions and noncurrent-version handling, a prefix-and-tags
filter, and an object-size filter that moves large objects into
`INTELLIGENT_TIERING`; an Intelligent-Tiering archive configuration for those
objects; server access logging with date-partitioned keys; a CORS rule for
browser uploads; both upload guardrails; and two declared policy statements
that let one role list and read `reports/`. Use it as a reference for the shape
of each input, then copy the parts you need.

Two details are easy to miss. The upload guardrails mean every `PutObject` must
send `x-amz-server-side-encryption: aws:kms` and the key ARN in
`x-amz-server-side-encryption-aws-kms-key-id`; a client that relies on default
encryption is denied. And the log destination must already grant
`logging.s3.amazonaws.com` permission to write under `<bucket>/`, which
`examples/access-logging` shows.

## Run

The example takes several environment-specific inputs, so a `terraform.tfvars`
is easier than `-var` flags:

```hcl
bucket          = "orders-data-123456789012"
kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
log_bucket      = "orders-logs-123456789012"
reader_role_arn = "arn:aws:iam::123456789012:role/analytics"
allowed_origins = ["https://app.example.com"]
```

```sh
terraform init && terraform plan
```

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
| <a name="module_bucket"></a> [bucket](#module\_bucket) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_origins"></a> [allowed\_origins](#input\_allowed\_origins) | Origins allowed to GET and PUT objects from a browser through CORS. | `set(string)` | n/a | yes |
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Globally unique bucket name. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer managed KMS key ARN for default encryption. Uploads must name it in the x-amz-server-side-encryption-aws-kms-key-id header. | `string` | n/a | yes |
| <a name="input_log_bucket"></a> [log\_bucket](#input\_log\_bucket) | Existing bucket that receives server access logs. It must use SSE-S3 and allow logging.s3.amazonaws.com to put objects under <bucket>/ (see examples/access-logging). | `string` | n/a | yes |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition, used to build ARNs in the bucket policy. | `string` | `"aws"` | no |
| <a name="input_reader_role_arn"></a> [reader\_role\_arn](#input\_reader\_role\_arn) | IAM role ARN allowed to list and read objects under reports/. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the bucket is created in. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. | `map(string)` | <pre>{<br/>  "Environment": "production",<br/>  "Team": "orders"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the bucket. |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Global domain name of the bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the bucket. |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the bucket. |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id) | Route 53 hosted zone ID for alias records to the bucket. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | Customer managed key used for default encryption. |
| <a name="output_lifecycle_rule_ids"></a> [lifecycle\_rule\_ids](#output\_lifecycle\_rule\_ids) | Ids of the lifecycle rules, sorted. |
| <a name="output_policy"></a> [policy](#output\_policy) | Composed bucket policy: the three guardrails plus the reader statements. |
| <a name="output_region"></a> [region](#output\_region) | Region the bucket resides in. |
| <a name="output_sse_algorithm"></a> [sse\_algorithm](#output\_sse\_algorithm) | Default encryption algorithm. |
| <a name="output_versioning"></a> [versioning](#output\_versioning) | Versioning state. |
<!-- END_TF_DOCS -->
