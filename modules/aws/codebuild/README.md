# codebuild

A CodeBuild project with a dedicated IAM role trusted only by the CodeBuild service, a CloudWatch Logs group this module owns, and IAM permissions scoped to that log group plus (only when configured) the specific source/artifact S3 buckets in use.

Privileged mode (Docker-in-Docker) defaults to `false`. It is a real variable rather than a hardcoded value because building container images is a legitimate use case — but the shared, mandatory `policy/aws/modules/codebuild.rego` rule denies any plan that sets it `true`. Enabling it for real means changing that shared policy, which is a reviewable commit, not a per-project toggle.

## Usage

```hcl
module "ci" {
  source = "github.com/JanitaM/infra-modules//modules/aws/codebuild?ref=v1.0.0"

  project_name    = "example-ci"
  source_type     = "GITHUB"
  source_location = "https://github.com/JanitaM/example-basic-site.git"

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `project_name` | CodeBuild project name | `string` | — (required) |
| `description` | Project description | `string` | `""` |
| `source_type` | `GITHUB` or `S3` | `string` | — (required) |
| `source_location` | Repo URL (GITHUB) or bucket/key (S3) | `string` | — (required) |
| `source_bucket_arn` | Source bucket ARN, for IAM scoping. Required when `source_type = S3` | `string` | `null` |
| `buildspec` | Path to buildspec within the source | `string` | `""` |
| `environment_compute_type` | `BUILD_GENERAL1_SMALL`/`MEDIUM`/`LARGE` | `string` | `"BUILD_GENERAL1_SMALL"` |
| `environment_image` | Build image | `string` | `"aws/codebuild/standard:7.0"` |
| `environment_type` | `LINUX_CONTAINER`/`LINUX_GPU_CONTAINER`/`ARM_CONTAINER` | `string` | `"LINUX_CONTAINER"` |
| `privileged_mode` | Enables Docker-in-Docker. Blocked by policy when `true` | `bool` | `false` |
| `environment_variables` | Plaintext build environment variables | `map(string)` | `{}` |
| `artifact_type` | `NO_ARTIFACTS` or `S3` | `string` | `"NO_ARTIFACTS"` |
| `artifact_bucket_name` | Artifact bucket name. Required when `artifact_type = S3` | `string` | `null` |
| `artifact_bucket_arn` | Artifact bucket ARN, for IAM scoping. Required when `artifact_type = S3` | `string` | `null` |
| `build_timeout` | Build timeout, in minutes | `number` | `15` |
| `log_retention_days` | CloudWatch Logs retention | `number` | `30` |
| `tags` | Tags applied to the project, role, and log group | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `project_name` | Project name |
| `project_arn` | Project ARN |
| `role_arn` | Build role ARN |
| `log_group_name` | CloudWatch Logs group name |

## What this module always does, with no opt-out

- Creates a dedicated IAM role trusted only by `codebuild.amazonaws.com`
- Creates and manages the project's CloudWatch Logs group itself, with an explicit retention period, rather than relying on CodeBuild's implicit unmanaged group
- Scopes the build role's log permissions to this project's own log group only, never a wildcard log group
- Scopes any source/artifact S3 permissions to the exact bucket ARNs passed in, never `*`
