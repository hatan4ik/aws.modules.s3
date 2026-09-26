# Contributing

Thank you for improving `aws.modules.s3`. This guide covers the toolchain, the local quality gate, how features are tested and where they belong, commit and pull request conventions, and how releases are cut.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in every README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy | `pip install checkov` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

## Integration suites

`tests/integration/` holds credential-driven suites that apply the module for real and destroy everything afterwards. They are never part of `make check` or the quality pipeline. Run them against your own account before a release that touches resource behaviour:

```bash
export AWS_PROFILE=<profile> AWS_REGION=<region>
make integration-smoke   # a bucket with versioning, SSE-KMS under the AWS managed key, a lifecycle rule, and the deny-insecure-transport policy; no charge beyond storage
```

Add a suite when a feature's correctness depends on the AWS API rather than on rendering (for example a new server-side encryption combination or a logging destination). Keep every value derived from the environment (a random suffix on every bucket name from `tests/integration/setup`), `force_destroy = true` so teardown can delete the bucket, and never reference a real account, bucket, or key.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make init` | `terraform init -backend=false` in the root, `modules/bucket-policy`, every example directory, and the integration fixture. |
| `make validate` | `make init` followed by `terraform validate` in each of those directories. |
| `make lint` | `tflint --init` and then `tflint` in every directory with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root and in `modules/bucket-policy`. No credentials are needed. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in every directory with terraform-docs v0.20.0, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when a README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --framework terraform`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. A skip needs an inline `checkov:skip=` comment with a reason on the resource it concerns. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. CI runs `terraform init` before the docs drift check, so a lock file missing a platform hash gets rewritten and fails that check. |
| `make integration-smoke` | The integration suite above, against the account and region in your environment. |
| `make clean` | Remove every `.terraform` directory and every lock file below the root. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

## Test-first workflow

Every behaviour in this module is pinned by a test before it is implemented. Write the failing `run` block first, then the code, then run `make test`.

- Root tests live in `tests/*.tftest.hcl` (`defaults` for secure-default assertions, `features` for every optional group rendering, `policy` for the composition and override paths, `validation` for every precondition and validation), and `modules/bucket-policy/tests/bucket_policy.tftest.hcl` for the renderer. Each file starts with `mock_provider "aws" {}` (the submodule needs none) and a `variables` block holding a valid baseline; each `run` overrides only what it exercises.
- Use `command = plan`. Nothing here talks to AWS, so tests run in seconds and in CI without credentials. Keep an `apply`-based run (needed to resolve a genuinely computed attribute) in a file of its own: `run` blocks in one `.tftest.hcl` file share state sequentially, so resources an `apply` run creates would otherwise leak into a later `plan` run in the same file.
- Validations are tested with `expect_failures`. Point it at the object that carries the check: `[var.bucket]` for a variable validation, `[aws_s3_bucket_server_side_encryption_configuration.this]` for a root precondition, `[output.json]` for the submodule's output precondition, `[check.versioning_not_enabled]` for a `check` block. A run with `expect_failures` passes only if exactly those objects fail; a run that triggers a `check` as a side effect must list it too. Add a positive run alongside so the happy path is covered.
- Assertions must not depend on unknown values. With a mock provider, computed attributes such as bucket ARNs beyond what the module itself derives are unknown at plan time, so assert on arguments you set, on counts and instance keys, and on outputs derived from inputs.
- `||` and `&&` do not short-circuit in Terraform 1.7. Both operands are always evaluated, so `var.x == null || var.x.field > 0` fails when `x` is null. Guard with a conditional instead: `var.x == null ? true : var.x.field > 0`. This applies to validations, preconditions, and test assertions alike.
- Keep assertion `error_message` text a statement of the guaranteed behaviour. It becomes the documentation of the contract when a test fails.

## Where to add a feature

`modules/bucket-policy` owns the shape of the bucket policy document and nothing else; the root owns the bucket and every other S3 API concern, one resource per concern.

| Concern | Lives in |
| --- | --- |
| A policy statement shape, a guardrail, principal or condition rendering, Sid validation | `modules/bucket-policy`: add or change the variable with validation, render it in `main.tf`, add a test. Then thread it through the root's `bucket_policy_statements`/guardrail inputs and the `module "bucket_policy"` call in `main.tf`. |
| A bucket-level resource (versioning, encryption, Object Lock, lifecycle, Intelligent-Tiering, logging, CORS) | Root `main.tf`: one resource or `dynamic` block per S3 API concern, gated by `count`/`for_each` on its own input so it renders only when declared. Add the input to `variables.tf` with validation, expose what a caller needs in `outputs.tf`, add a test. |
| A cross-variable rule the type system cannot express (Object Lock needing versioning, a KMS-only setting used with AES256) | A `lifecycle.precondition` on the resource it guards, never a `validation` block, and never `terraform_data`. |
| A situation that is valid but usually unintended | `checks.tf`, with a `terraform test` `expect_failures` case against the `check`. |
| Outputs | Root `outputs.tf`. Keep every output a flat, named identifier; do not reintroduce a compatibility struct. |

Rules that apply everywhere: no data sources (derive the bucket ARN from `partition` and `bucket`, never look it up), every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time, every output has a description, defaults are the secure choice (nothing public, nothing unencrypted, nothing unversioned unless declared), and any new managed resource that a caller might already own gets a way to supply it instead so outputs stay identical either way.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the submodule or root file the change touches.

```text
feat(bucket-policy): support Federated principals
fix(lifecycle): reject a transition with both days and date
docs: explain filter combination rules
test(validation): cover Intelligent-Tiering tier day bounds
feat!: rename bucket_policy_json to policy_json_override
```

Append `!` after the type or scope for a breaking change and add a `BREAKING CHANGE:` footer explaining what consumers must do. Breaking changes ship only in a major release with an entry in the upgrade guide.

## Pull request checklist

- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated the README tables with terraform-docs v0.20.0.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Breaking changes carry `!`, a `BREAKING CHANGE:` footer, and an update to `docs/UPGRADE-<major>.md`.
- [ ] Examples still initialise and validate; a new feature worth showing has an example.
- [ ] No data sources, no hard-coded account, region, or partition, no new defaults that weaken security.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Create a signed annotated tag on the merge commit. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git tag -s vX.Y.Z -m "aws.modules.s3 vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag with `release_tag = vX.Y.Z`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. It verifies the signed tag, formatting, validation, tests, and generated docs, then publishes the GitHub release. Never dispatch it from `main`: the workflow checks that the tag points at the revision it checked out, and a maintenance release of an older line is cut from that line's commit.
4. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.s3.git?ref=<commit-sha>" # vX.Y.Z
   ```

Tags are never moved or deleted once published. A bad release is followed by a new patch release.
