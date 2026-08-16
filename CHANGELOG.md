# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `additional_policy_arns` on `modules/aws/lambda-function-url` — attaches existing scoped policies to the function's execution role, in addition to the CloudWatch Logs baseline. `examples/aws/basic-site` now wires `api_handler` to the `api_key`/`feature_flags`/`mail` modules' policy ARNs, which previously had no consumer in the example.
- `.github/dependabot.yml` — weekly checks for GitHub Actions version bumps.
- `checkov` CI job plus `.checkov.yaml` — a real blocking static-analysis gate against `modules/aws`, alongside the curated `policy/aws` rego rules. Every skipped check is individually justified in `.checkov.yaml`. See `README.md`'s "Static analysis" section.

## [1.0.0] - 2026-08-16

### Added

- `modules/aws/s3-bucket` and `policy/aws/global.rego`'s "no public S3" rule — the first module and the first policy, proving the module → plan → policy pipeline end to end.
- `modules/aws/dynamodb-table`, plus `global.rego` rules requiring encryption at rest and point-in-time recovery. `examples/aws/sessions-table` shows it standalone.
- `modules/aws/lambda-function-url`, plus a rule requiring `AWS_IAM` authorization (never a public function URL). `examples/aws/webhook-handler` shows it standalone.
- `modules/aws/cloudfront-distribution`, plus a rule requiring a WAF web ACL on the distribution.
- `modules/aws/cognito`, plus a rule requiring MFA on the user pool.
- `modules/aws/ses`, plus `global.rego`'s "no wildcard IAM action/resource" rule (shared across every module that authors an IAM policy document).
- `modules/aws/route53`, plus a rule requiring DNSSEC signing on public hosted zones.
- `modules/aws/codebuild`, plus a rule forbidding `environment.privileged_mode`.
- `modules/aws/secrets-manager`, plus a rule forbidding a wildcard principal in the resource policy.
- `modules/aws/ssm`, plus a rule requiring parameter type `SecureString`.
- `modules/aws/cloudwatch` (SNS topic), plus a rule requiring `kms_master_key_id`.
- `modules/aws/budget`, plus a rule requiring at least one notification subscriber.
- `modules/aws/iam-role` — attaches a caller-supplied trust policy plus existing policy ARNs from other modules; authors no policy document itself.
- `examples/aws/basic-site` — a working root config wiring every AWS module above together.
- `policy/aws/testdata/` — `allow`/`deny-*.json` fixture plan JSON for every module rule and for `global.rego`'s S3/DynamoDB/IAM intents.
- `scripts/test-policy-fixtures.sh` — checks each fixture individually against its `allow`/`deny-*` filename convention; `conftest test` on a whole fixture directory at once collapses pass/fail cases into one aggregate result and can hide a regression.
- `scripts/check-manifest.sh` — validates a consuming project's `infra-modules.yml` and that every module `source` ref's `?ref=` matches the declared `module_version`.
- `.github/workflows/ci.yml` — runs the policy fixtures and `terraform fmt`/`validate` across every module and example on every push/PR to `main`.
- `CHANGELOG.md`, this file.
