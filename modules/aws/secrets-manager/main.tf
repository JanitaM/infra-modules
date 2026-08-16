terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# SC-28: encrypted at rest by default with the AWS-managed key, or a
# customer-managed key when var.kms_key_id is set.
resource "aws_secretsmanager_secret" "primary" {
  name                    = var.secret_name
  description             = var.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "primary" {
  count         = var.secret_string != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.primary.id
  secret_string = var.secret_string
}

# AC-3: resource policy is opt-in — a secret with none is only reachable via
# IAM on the caller's own credentials. See policy/aws/modules/secrets-manager.rego
# for the plan-time check that any policy attached here never grants a
# wildcard principal.
resource "aws_secretsmanager_secret_policy" "primary" {
  count      = var.resource_policy_json != null ? 1 : 0
  secret_arn = aws_secretsmanager_secret.primary.arn
  policy     = var.resource_policy_json
}

# AC-6: read permission scoped to this secret's ARN only, no wildcard
# resource/action — attach to a consumer's own role to grant read access.
data "aws_iam_policy_document" "read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.primary.arn]
  }
}

resource "aws_iam_policy" "read" {
  # IAM policy names can't contain "/", unlike Secrets Manager names, which
  # commonly use it as a path separator (e.g. "prod/db-password").
  name        = "${replace(var.secret_name, "/", "-")}-secrets-read"
  description = "Allows reading the ${var.secret_name} secret only."
  policy      = data.aws_iam_policy_document.read.json
  tags        = var.tags
}
