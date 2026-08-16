# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

No version has been tagged yet, so everything to date is listed under
`[Unreleased]`.

## [Unreleased]

### Added

- `modules/aws/s3-bucket` and `policy/aws/global.rego`'s "no public S3" rule — the first module and the first policy, proving the module → plan → policy pipeline end to end.
- `modules/aws/dynamodb-table`, plus `global.rego` rules requiring encryption at rest and point-in-time recovery.
- `modules/aws/lambda-function-url`, plus a rule requiring `AWS_IAM` authorization (never a public function URL).
- `modules/aws/cloudfront-distribution`, plus a rule requiring a WAF web ACL on the distribution.
- `modules/aws/cognito`, plus a rule requiring MFA on the user pool.
- `modules/aws/ses`, plus `global.rego`'s "no wildcard IAM action/resource" rule (shared across every module that authors an IAM policy document).
- `modules/aws/route53`, plus a rule requiring DNSSEC signing on public hosted zones.
- `modules/aws/codebuild`, plus a rule forbidding `environment.privileged_mode`.
- `modules/aws/secrets-manager`, plus a rule forbidding a wildcard principal in the resource policy.
- `modules/aws/ssm`, plus a rule requiring parameter type `SecureString`.
- `modules/aws/cloudwatch` (SNS topic), plus a rule requiring `kms_master_key_id`.
- `modules/aws/budget`, plus a rule requiring at least one notification subscriber.
- `examples/aws/basic-site` — a working root config wiring every module above together.
- `policy/aws/testdata/` — `allow`/`deny-*.json` fixture plan JSON for every module rule and for `global.rego`'s S3/DynamoDB/IAM intents, run via `conftest test`. See `README.md`'s "Testing policy rules" section.
- `modules/aws/iam-role` — attaches a caller-supplied trust policy plus existing policy ARNs from other modules; authors no policy document itself.
- `scripts/check-manifest.sh` — validates a consuming project's `infra-modules.yml` and that every module `source` ref's `?ref=` matches the declared `module_version`.
