# Multiple buckets

Creates a set of buckets from one root module by using `for_each` on the module
block. `aws.modules.s3` provisions exactly one bucket per call on purpose: a
bucket is the unit that gets its own policy, lifecycle rules, encryption
settings and Object Lock state, and a plan error names the one bucket that
caused it. Fleets are therefore expressed in the caller, as a map of bucket
specifications, not as a list inside the module.

Each entry may pin its versioning state, a customer managed KMS key, and an
expiration for its objects; the module derives `<name_prefix>-<key>` and keeps
every other secure default. Adding a bucket is adding a map entry; removing one
destroys exactly that bucket (and refuses while it holds objects, because
`force_destroy` stays `false`).

## Run

Declare the fleet in a `terraform.tfvars`:

```hcl
name_prefix = "orders-123456789012"

buckets = {
  raw = {
    expire_after_days = 30
  }
  curated = {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }
  scratch = {
    versioning        = "Suspended"
    expire_after_days = 7
  }
}
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
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Buckets to create, keyed by a short dataset name. Each may pin its versioning state, a customer managed KMS key (null uses the AWS managed key), and an expiration in days for its objects. | <pre>map(object({<br/>    versioning        = optional(string, "Enabled")<br/>    kms_key_arn       = optional(string)<br/>    expire_after_days = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for every bucket name; the map key is appended (<prefix>-<key>). Include an account or team identifier so the names are globally unique. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region every bucket is created in. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | Bucket ARNs keyed by dataset name. |
| <a name="output_bucket_ids"></a> [bucket\_ids](#output\_bucket\_ids) | Bucket names keyed by dataset name. |
| <a name="output_bucket_regional_domain_names"></a> [bucket\_regional\_domain\_names](#output\_bucket\_regional\_domain\_names) | Regional domain names keyed by dataset name. |
<!-- END_TF_DOCS -->
