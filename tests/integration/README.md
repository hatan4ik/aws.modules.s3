# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use the AWS
documentation placeholder account `123456789012` and placeholder ARNs on
purpose: they prove the module's interface and rendering, not that AWS accepts
it. These suites prove the latter.

Nothing here is tied to an account, region, or landing zone. Credentials and
the region come from the environment; the only prerequisite is a globally
unique bucket name, which [`setup/`](setup/) generates with a random suffix so
concurrent runs never collide. The fixture creates no AWS resource.

| Suite | What it proves | Needs | Typical time |
| --- | --- | --- | --- |
| `smoke.tftest.hcl` | A bucket with the module's defaults (public access block, enforced ownership, versioning, SSE-KMS under the AWS managed key with a Bucket Key, the deny-insecure-transport policy) plus one lifecycle rule is accepted by the S3 API, and the outputs resolve from the real bucket. `force_destroy = true` so teardown deletes it. | credentials, region | about 1 minute |

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json),
scoped to bucket names starting with `s3-it-`, which is what the fixture
produces. No KMS permission is needed: the suite encrypts under the AWS managed
`aws/s3` key, which S3 uses on the caller's behalf.

`terraform test` runs `tests/` only by default, so these suites never run in
the credential-free quality pipeline. The fixture module is excluded from the
Checkov and Trivy scans (`.checkov.yml`, `trivy.yaml`) because it is
short-lived test scaffolding, not a deployable pattern.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region for the disposable bucket. |

Dispatch with `gh workflow run integration.yml -f suite=smoke`. Protect the
environment with required reviewers so a run cannot be started from a pull
request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.s3:environment:integration`.
