# SC-28: type is hardcoded to SecureString, no opt-out. A plaintext String or
# StringList value is readable by anyone with ssm:GetParameter alone — no KMS
# decrypt permission required — unlike SecureString, which needs both. See
# policy/aws/modules/ssm.rego for the plan-time check that also catches a
# parameter someone writes by hand instead of through this module.
resource "aws_ssm_parameter" "primary" {
  name        = var.parameter_name
  description = var.description
  type        = "SecureString"
  value       = var.value
  key_id      = var.kms_key_id
  tier        = var.tier
  tags        = var.tags
}

# Resolves the AWS-managed key's ARN when no customer-managed key was given,
# so the read policy below can grant kms:Decrypt on whichever key actually
# encrypts this parameter.
data "aws_kms_alias" "ssm_default" {
  count = var.kms_key_id == null ? 1 : 0
  name  = "alias/aws/ssm"
}

locals {
  kms_key_arn = var.kms_key_id != null ? var.kms_key_id : data.aws_kms_alias.ssm_default[0].target_key_arn
}

# AC-6: read permission scoped to this parameter's ARN and its encryption
# key only, no wildcard resource/action — attach to a consumer's own role.
data "aws_iam_policy_document" "read" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [aws_ssm_parameter.primary.arn]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [local.kms_key_arn]
  }
}

resource "aws_iam_policy" "read" {
  # IAM policy names can't contain "/", unlike SSM parameter names, which
  # commonly use it as a path separator (e.g. "/prod/db-password").
  name        = "${replace(var.parameter_name, "/", "-")}-ssm-read"
  description = "Allows reading the ${var.parameter_name} SSM parameter only."
  policy      = data.aws_iam_policy_document.read.json
  tags        = var.tags
}
