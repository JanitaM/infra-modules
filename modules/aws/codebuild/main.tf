terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# AC-3: trust policy scoped to the CodeBuild service only — nothing else can assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "primary" {
  name               = "${var.project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# This module owns the log group (rather than letting CodeBuild create an
# unmanaged one implicitly) so retention is always explicitly set.
resource "aws_cloudwatch_log_group" "primary" {
  name              = "/aws/codebuild/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# AC-6: log permissions scoped to this project's own log group only — never a
# wildcard log group.
data "aws_iam_policy_document" "logs" {
  statement {
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      aws_cloudwatch_log_group.primary.arn,
      "${aws_cloudwatch_log_group.primary.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${var.project_name}-logs"
  role   = aws_iam_role.primary.id
  policy = data.aws_iam_policy_document.logs.json
}

# AC-6: read access scoped to the single source bucket, only created when
# source_type == "S3" — GITHUB sources need no S3 permissions at all.
data "aws_iam_policy_document" "source_s3" {
  count = var.source_type == "S3" ? 1 : 0
  statement {
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${var.source_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "source_s3" {
  count  = var.source_type == "S3" ? 1 : 0
  name   = "${var.project_name}-source-s3"
  role   = aws_iam_role.primary.id
  policy = data.aws_iam_policy_document.source_s3[0].json
}

# AC-6: write access scoped to the single artifact bucket, only created when
# artifact_type == "S3".
data "aws_iam_policy_document" "artifacts_s3" {
  count = var.artifact_type == "S3" ? 1 : 0
  statement {
    actions   = ["s3:PutObject", "s3:GetBucketAcl", "s3:GetBucketLocation"]
    resources = [var.artifact_bucket_arn, "${var.artifact_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "artifacts_s3" {
  count  = var.artifact_type == "S3" ? 1 : 0
  name   = "${var.project_name}-artifacts-s3"
  role   = aws_iam_role.primary.id
  policy = data.aws_iam_policy_document.artifacts_s3[0].json
}

resource "aws_codebuild_project" "primary" {
  name          = var.project_name
  description   = var.description
  service_role  = aws_iam_role.primary.arn
  build_timeout = var.build_timeout

  source {
    type      = var.source_type
    location  = var.source_location
    buildspec = var.buildspec != "" ? var.buildspec : null
  }

  artifacts {
    type     = var.artifact_type
    name     = var.artifact_type == "S3" ? var.project_name : null
    location = var.artifact_type == "S3" ? var.artifact_bucket_name : null
  }

  # SC-7 / AC-6: privileged_mode defaults to false. It is a real, settable
  # variable (unlike this module's hardcoded security choices elsewhere)
  # because container-image builds are a legitimate use case — but flipping
  # it stays visible in plan output, and policy/aws/modules/codebuild.rego
  # denies any plan that sets it true.
  environment {
    compute_type    = var.environment_compute_type
    image           = var.environment_image
    type            = var.environment_type
    privileged_mode = var.privileged_mode

    dynamic "environment_variable" {
      for_each = var.environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.primary.name
      status     = "ENABLED"
    }
  }

  tags = var.tags
}
