# Minimal bucket

The smallest working call of `aws.modules.s3`: a bucket name and tags. It
creates seven resources and every one of them is a secure default: the bucket,
a public access block with all four settings on, `BucketOwnerEnforced`
ownership (ACLs disabled), versioning `Enabled`, default encryption with
SSE-KMS under the AWS managed `aws/s3` key and an S3 Bucket Key, and a bucket
policy whose only statement denies every request that does not use TLS.
Nothing else exists until you declare it: no lifecycle rules, no logging, no
CORS, no Object Lock. Start here to see what a bucket needs before layering on
features.

## Run

```sh
terraform init
terraform plan -var bucket=orders-data-123456789012
```

Bucket names are global, so pick one that includes an account or team
identifier. `force_destroy` keeps its default of `false`: `terraform destroy`
refuses to delete the bucket while it holds objects.

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
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Globally unique bucket name (3-63 lowercase letters, digits, dots, or hyphens). | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the bucket is created in. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the bucket. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the bucket. |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional domain name of the bucket. |
| <a name="output_policy"></a> [policy](#output\_policy) | Bucket policy the module attached: the DenyInsecureTransport statement only. |
<!-- END_TF_DOCS -->
