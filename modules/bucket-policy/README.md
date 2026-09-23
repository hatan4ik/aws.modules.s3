# bucket-policy

Renders one S3 bucket policy document from typed inputs: a map of statements keyed by Sid plus three opt-in guardrails that deny insecure transport, uploads without the required encryption header, and uploads with the wrong KMS key. It creates no resources and declares no provider, so the policy shape has a single owner and is unit-tested with `terraform test` alone. The root module calls it once per bucket; call it directly to build a policy for a bucket the root module does not manage, or to review the document a set of inputs produces before applying it.

## Usage

```hcl
module "policy" {
  source = "git::https://github.com/hatan4ik/aws.modules.s3.git//modules/bucket-policy?ref=<commit-sha>" # v1.0.0

  bucket_arn = "arn:aws:s3:::orders-data"

  deny_unencrypted_object_uploads = true
  deny_incorrect_encryption_key   = true
  kms_key_arn                     = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"

  statements = {
    ReadForAnalytics = {
      principals = { AWS = ["arn:aws:iam::123456789012:role/analytics"] }
      actions    = ["s3:GetObject", "s3:ListBucket"]
      conditions = [
        { test = "StringEquals", variable = "aws:PrincipalOrgID", values = ["o-abcdef1234"] },
        { test = "StringLike", variable = "s3:prefix", values = ["reports/*"] },
      ]
    }
    AllowLogDelivery = {
      principals = { Service = ["logging.s3.amazonaws.com"] }
      actions    = ["s3:PutObject"]
      resources  = ["arn:aws:s3:::orders-data/logs/*"]
      conditions = [
        { test = "StringEquals", variable = "aws:SourceAccount", values = ["123456789012"] },
        { test = "ArnLike", variable = "aws:SourceArn", values = ["arn:aws:s3:::orders-app"] },
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = module.policy.json == null ? 0 : 1

  bucket = "orders-data"
  policy = module.policy.json
}
```

## Behaviour

- Rendering. Every statement renders `Sid`, `Effect`, `Principal`, `Action`, and `Resource`, plus `Condition` only when conditions are declared. Actions, resources, principal identifiers, and condition values are rendered as sorted lists; principal types are sorted; conditions are grouped by test (`{ "StringEquals": { "aws:PrincipalOrgID": [...], "s3:prefix": [...] } }`). Statements are sorted by Sid, so the document changes only when an input changes.
- Principals. Name them by type in `principals` (`AWS`, `Service`, `Federated`, `CanonicalUser`, each a set of identifiers) or set `principal_all = true` for `"Principal": "*"`. Exactly one of the two forms is required.
- Resources. `resources` defaults to the bucket and its objects (`bucket_arn` and `bucket_arn/*`). Every declared resource must be `bucket_arn` or a path under it; the S3 API rejects a bucket policy that names another bucket, so the module rejects it at plan time.
- `DenyInsecureTransport` (`deny_insecure_transport`, default true). `Deny s3:*` for `"Principal": "*"` on the bucket and its objects with `Bool aws:SecureTransport = false`. This is the CIS and AWS Foundational Security Best Practices control for S3 buckets.
- `DenyUnencryptedObjectUploads` (`deny_unencrypted_object_uploads`, default false). `Deny s3:PutObject` on objects with `StringNotEquals s3:x-amz-server-side-encryption = required_sse_algorithm`. Clients must send the header with that algorithm; a request that omits the header and relies on the bucket's default encryption is denied, because a missing key satisfies a negated condition. Pair it with the bucket's default encryption so the two agree.
- `DenyIncorrectEncryptionKey` (`deny_incorrect_encryption_key`, default false). `Deny s3:PutObject` on objects with `StringNotEquals s3:x-amz-server-side-encryption-aws-kms-key-id = kms_key_arn`. Requires `kms_key_arn` as a key ARN (not an ID or alias) because S3 evaluates the condition against the ARN. Clients must name the key in the header for the same reason as above.
- Reserved Sids. The three guardrail Sids cannot be used as `statements` keys; enable the guardrails with their flags instead.
- Empty document. When no guardrail is enabled and no statement is declared, `json` is `null` and `statement_count` is 0, so a caller can make the policy resource conditional on it.
- Validation, all at plan time: Sids are alphanumeric; `effect` is `Allow` or `Deny`; `actions` is non-empty; principals use a known type with at least one identifier; declared `resources` are non-empty; every condition has a test, a variable, and at least one value; `bucket_arn` is an S3 bucket ARN; `required_sse_algorithm` is `aws:kms`, `AES256`, or `aws:kms:dsse`; `kms_key_arn` is a KMS key ARN.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn) | ARN of the bucket the policy applies to (arn:<partition>:s3:::<name>). Statement resources default to this ARN and its objects, and every declared resource must lie within it. | `string` | n/a | yes |
| <a name="input_deny_incorrect_encryption_key"></a> [deny\_incorrect\_encryption\_key](#input\_deny\_incorrect\_encryption\_key) | Add the DenyIncorrectEncryptionKey statement: deny s3:PutObject unless the x-amz-server-side-encryption-aws-kms-key-id header names kms\_key\_arn. Requires kms\_key\_arn. | `bool` | `false` | no |
| <a name="input_deny_insecure_transport"></a> [deny\_insecure\_transport](#input\_deny\_insecure\_transport) | Add the DenyInsecureTransport statement: deny every S3 action on the bucket and its objects when the request does not use TLS (aws:SecureTransport is false). | `bool` | `true` | no |
| <a name="input_deny_unencrypted_object_uploads"></a> [deny\_unencrypted\_object\_uploads](#input\_deny\_unencrypted\_object\_uploads) | Add the DenyUnencryptedObjectUploads statement: deny s3:PutObject unless the x-amz-server-side-encryption header names required\_sse\_algorithm. Requests that omit the header and rely on the bucket default encryption are denied too. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN (arn:<partition>:kms:<region>:<account>:key/<id>) that uploads must use when deny\_incorrect\_encryption\_key is set. Key IDs and aliases are not accepted because S3 evaluates the condition against the key ARN. | `string` | `null` | no |
| <a name="input_required_sse_algorithm"></a> [required\_sse\_algorithm](#input\_required\_sse\_algorithm) | Server-side encryption algorithm the upload guardrail requires in the x-amz-server-side-encryption header: aws:kms, AES256, or aws:kms:dsse. | `string` | `"aws:kms"` | no |
| <a name="input_statements"></a> [statements](#input\_statements) | Policy statements keyed by alphanumeric Sid. Each names its principals by type (AWS, Service, Federated, CanonicalUser) or sets principal\_all for the wildcard principal, lists actions, optionally restricts resources (default: the bucket and its objects), and may add conditions that are grouped by test. The guardrail Sids DenyInsecureTransport, DenyUnencryptedObjectUploads, and DenyIncorrectEncryptionKey are reserved. | <pre>map(object({<br/>    effect        = optional(string, "Allow")<br/>    principals    = optional(map(set(string)), {})<br/>    principal_all = optional(bool, false)<br/>    actions       = set(string)<br/>    resources     = optional(set(string))<br/>    conditions = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = set(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_json"></a> [json](#output\_json) | Rendered bucket policy document, sorted by Sid, or null when no guardrail is enabled and no statement is declared. |
| <a name="output_statement_count"></a> [statement\_count](#output\_statement\_count) | Number of statements in the rendered document, including enabled guardrails. |
<!-- END_TF_DOCS -->
