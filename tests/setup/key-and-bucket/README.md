# Contract test fixture: key and bucket in one configuration

A root that creates a KMS key and the module's bucket together, so the key ARN
handed to `kms_key_arn` is a computed attribute, unknown while the plan is
built. `tests/policy_attachment.tftest.hcl` plans it under `mock_provider` to
prove that the module decides whether to attach a bucket policy from its
inputs, never from the rendered document, which is known only after apply once
a statement names the key. `terraform test` evaluates the fixture and discards
it; nothing is created. It is not a deployable pattern and is excluded from
policy scans (see `.checkov.yml` and `trivy.yaml` at the repository root).

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
| <a name="module_bucket"></a> [bucket](#module\_bucket) | ../../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Name of the bucket under test. | `string` | `"orders-data"` | no |
| <a name="input_deny_incorrect_encryption_key"></a> [deny\_incorrect\_encryption\_key](#input\_deny\_incorrect\_encryption\_key) | Passed through to the module's deny\_incorrect\_encryption\_key; the rendered statement then names the key ARN, which is unknown until apply. | `bool` | `false` | no |
| <a name="input_deny_insecure_transport"></a> [deny\_insecure\_transport](#input\_deny\_insecure\_transport) | Passed through to the module's deny\_insecure\_transport. | `bool` | `true` | no |
| <a name="input_deny_unencrypted_object_uploads"></a> [deny\_unencrypted\_object\_uploads](#input\_deny\_unencrypted\_object\_uploads) | Passed through to the module's deny\_unencrypted\_object\_uploads. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_policy"></a> [policy](#output\_policy) | The module's policy output: the document attached to the bucket, or null when none is. Known at plan only while no statement names the key. |
<!-- END_TF_DOCS -->
