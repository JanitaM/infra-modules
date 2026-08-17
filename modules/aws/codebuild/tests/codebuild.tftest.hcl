# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# mock_provider mocks data sources too, not just resources — including
# aws_iam_policy_document, which is normally computed locally by the
# provider (no real API call), not read from anywhere. Its json output
# comes back invalid unless overridden explicitly.
mock_provider "aws" {
  override_data {
    target = data.aws_iam_policy_document.assume_role
    values = {
      json = "{}"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.logs
    values = {
      json = "{}"
    }
  }
}

variables {
  project_name    = "test-project"
  source_type     = "GITHUB"
  source_location = "https://github.com/example/repo.git"
}

run "no_s3_policies_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.source_s3) == 0
    error_message = "no source_s3 policy should be created when source_type is GITHUB"
  }

  assert {
    condition     = length(aws_iam_role_policy.artifacts_s3) == 0
    error_message = "no artifacts_s3 policy should be created when artifact_type is NO_ARTIFACTS"
  }
}

run "source_s3_policy_created_for_s3_source" {
  command = plan

  variables {
    source_type       = "S3"
    source_location   = "my-source-bucket/source.zip"
    source_bucket_arn = "arn:aws:s3:::my-source-bucket"
  }

  override_data {
    target = data.aws_iam_policy_document.source_s3[0]
    values = {
      json = "{}"
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.source_s3) == 1
    error_message = "a source_s3 policy should be created when source_type is S3"
  }
}

run "artifacts_s3_policy_created_for_s3_artifacts" {
  command = plan

  variables {
    artifact_type        = "S3"
    artifact_bucket_name = "my-artifact-bucket"
    artifact_bucket_arn  = "arn:aws:s3:::my-artifact-bucket"
  }

  override_data {
    target = data.aws_iam_policy_document.artifacts_s3[0]
    values = {
      json = "{}"
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.artifacts_s3) == 1
    error_message = "an artifacts_s3 policy should be created when artifact_type is S3"
  }
}

run "environment_variables_become_dynamic_blocks" {
  command = plan

  variables {
    environment_variables = {
      FOO = "bar"
    }
  }

  assert {
    condition     = tolist(aws_codebuild_project.primary.environment[0].environment_variable)[0].name == "FOO"
    error_message = "environment_variables entries should appear as environment_variable blocks"
  }
}

run "rejects_invalid_source_type" {
  command = plan

  variables {
    source_type = "BITBUCKET"
  }

  expect_failures = [var.source_type]
}

run "rejects_invalid_environment_compute_type" {
  command = plan

  variables {
    environment_compute_type = "BUILD_GENERAL1_XLARGE"
  }

  expect_failures = [var.environment_compute_type]
}

run "rejects_invalid_environment_type" {
  command = plan

  variables {
    environment_type = "WINDOWS_CONTAINER"
  }

  expect_failures = [var.environment_type]
}

run "rejects_invalid_artifact_type" {
  command = plan

  variables {
    artifact_type = "CODEPIPELINE"
  }

  expect_failures = [var.artifact_type]
}
