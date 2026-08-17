resource "aws_ses_domain_identity" "primary" {
  domain = var.domain
}

# IA-2: DKIM signs outbound mail from this identity so receiving servers can
# verify it wasn't spoofed — hardcoded, no opt-out.
resource "aws_ses_domain_dkim" "primary" {
  domain = aws_ses_domain_identity.primary.domain
}

# AC-6: sending permission scoped to this identity's ARN only, no wildcard
# resource/action. See policy/aws/global.rego for the plan-time check.
data "aws_iam_policy_document" "send" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [aws_ses_domain_identity.primary.arn]
  }
}

resource "aws_iam_policy" "send" {
  name        = "${var.domain}-ses-send"
  description = "Allows sending email via the ${var.domain} SES identity only."
  policy      = data.aws_iam_policy_document.send.json
  tags        = var.tags
}
