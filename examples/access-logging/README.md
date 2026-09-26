# Access logging

Two module calls: a log bucket and a data bucket that delivers its server
access logs to it. The module manages one bucket per call and never creates a
second one for logs, so the destination is declared beside the source and the
two are wired through the `logging` input and a policy statement.

The log bucket shows the three things a destination needs. Its default
encryption is SSE-S3 (`AES256`), because S3 delivers access logs only to SSE-S3
destinations. Its policy adds the statement AWS documents for log delivery: the
`logging.s3.amazonaws.com` service principal may `s3:PutObject` under the
source bucket's prefix, conditioned on `aws:SourceArn` (the source bucket) and
`aws:SourceAccount` (your account), expressed with the `bucket_policy_statements`
map so the `DenyInsecureTransport` guardrail stays in place beside it. And a
lifecycle rule expires log objects after `log_retention_days`.

The data bucket keeps every default and adds `logging` with date-partitioned
object keys (`[prefix][account]/[region]/[bucket]/[YYYY]/[MM]/[DD]/...`), which
Athena and log processors can prune by day. Its module block depends on the log
module because S3 accepts a logging configuration only once the destination
grants the logging service principal.

## Run

```sh
terraform init
terraform plan \
  -var account_id=123456789012 \
  -var data_bucket=orders-data-123456789012 \
  -var log_bucket=orders-logs-123456789012
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
| <a name="module_data"></a> [data](#module\_data) | ../../ | n/a |
| <a name="module_logs"></a> [logs](#module\_logs) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account that owns both buckets; the log delivery statement is conditioned on it. | `string` | n/a | yes |
| <a name="input_data_bucket"></a> [data\_bucket](#input\_data\_bucket) | Globally unique name of the bucket whose requests are logged. | `string` | n/a | yes |
| <a name="input_log_bucket"></a> [log\_bucket](#input\_log\_bucket) | Globally unique name of the bucket that receives the access logs. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days after which access log objects expire. | `number` | `400` | no |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition, used to build ARNs in the log delivery statement. | `string` | `"aws"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region both buckets are created in; access logs can only be delivered within a region. | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to both buckets. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_bucket_id"></a> [data\_bucket\_id](#output\_data\_bucket\_id) | Name of the logged bucket. |
| <a name="output_log_bucket_id"></a> [log\_bucket\_id](#output\_log\_bucket\_id) | Name of the log destination bucket. |
| <a name="output_log_bucket_policy"></a> [log\_bucket\_policy](#output\_log\_bucket\_policy) | Policy of the log bucket: DenyInsecureTransport plus the log delivery grant. |
<!-- END_TF_DOCS -->
