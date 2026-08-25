resource "aws_ses_domain_identity" "primary" {
  domain = var.domain
}

# IA-2: DKIM signs outbound mail from this identity so receiving servers can
# verify it wasn't spoofed — hardcoded, no opt-out.
resource "aws_ses_domain_dkim" "primary" {
  domain = aws_ses_domain_identity.primary.domain
}

# AC-6: sending permission scoped to this identity's ARN (and, when a
# configuration set exists, that ARN too) only, no wildcard resource/action.
# See policy/aws/global.rego for the plan-time check.
#
# SES enforces resource-level IAM on the configuration set named in
# SendEmailCommand's ConfigurationSetName, separately from the identity being
# sent from — confirmed live: a send using this policy without the
# configuration set's ARN included failed with AccessDenied on
# ses:SendEmail against the configuration-set resource, despite the identity
# ARN grant being present and correct.
data "aws_iam_policy_document" "send" {
  statement {
    actions = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = compact([
      aws_ses_domain_identity.primary.arn,
      local.create_config_set ? aws_ses_configuration_set.feedback[0].arn : null,
    ])
  }
}

resource "aws_iam_policy" "send" {
  name        = "${var.domain}-ses-send"
  description = "Allows sending email via the ${var.domain} SES identity only."
  policy      = data.aws_iam_policy_document.send.json
  tags        = var.tags
}

locals {
  # Something to route bounce/complaint events to: either the caller wants a
  # topic of ours (feedback_notification_email) or already has one to reuse
  # (existing_topic_arn). Either is enough reason to attach a configuration
  # set — with neither, one would sit with no event destination, dead weight.
  create_config_set = var.feedback_notification_email != null || var.existing_topic_arn != null
  create_topic      = local.create_config_set && var.existing_topic_arn == null
  topic_arn         = local.create_config_set ? coalesce(var.existing_topic_arn, one(aws_sns_topic.feedback[*].arn)) : null

  # aws_ses_event_destination's name (and, to stay consistent, the
  # configuration set's and topic's) only allows alphanumeric/underscore/
  # hyphen — a bare domain like "mail.example.com" is rejected for its dots.
  resource_name_prefix = replace(var.domain, ".", "-")
}

resource "aws_ses_configuration_set" "feedback" {
  count = local.create_config_set ? 1 : 0
  name  = "${local.resource_name_prefix}-feedback"

  # SC-8: reject sends over the set that can't negotiate TLS to the
  # recipient's MTA, rather than silently falling back to plaintext.
  delivery_options {
    tls_policy = "Require"
  }
}

data "aws_caller_identity" "current" {
  count = local.create_topic ? 1 : 0
}

locals {
  # true only when this module owns the key decision at all: no caller-supplied
  # key, and a topic to encrypt in the first place.
  create_kms_key = local.create_topic && var.kms_key_id == null
}

# The AWS-managed alias/aws/sns key cannot grant SES publish access — its
# policy isn't editable by a customer, at all, ever. A customer-managed key is
# the only way for feedback_notification_email's default (no kms_key_id
# supplied) to actually work, confirmed live: aws_ses_event_destination fails
# with InvalidSNSDestination ("Access denied to KMS key ...") against
# alias/aws/sns, on every attempt, regardless of what IAM/SNS policy exists.
resource "aws_kms_key" "feedback" {
  count               = local.create_kms_key ? 1 : 0
  description         = "Encrypts the ${var.domain} SES bounce/complaint SNS topic."
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.feedback_kms[0].json
  tags                = var.tags
}

resource "aws_kms_alias" "feedback" {
  count         = local.create_kms_key ? 1 : 0
  name          = "alias/${local.resource_name_prefix}-ses-feedback"
  target_key_id = aws_kms_key.feedback[0].key_id
}

data "aws_iam_policy_document" "feedback_kms" {
  count = local.create_kms_key ? 1 : 0

  # Every CMK's policy needs this: without an explicit grant to the account
  # root, IAM policies elsewhere in the account can never be used to permit
  # this key, no matter what they say — only principals named directly in the
  # key policy could use it at all.
  statement {
    sid     = "EnableRootAccountAccess"
    effect  = "Allow"
    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current[0].account_id}:root"]
    }

    resources = ["*"]
  }

  statement {
    sid     = "AllowSESPublish"
    effect  = "Allow"
    actions = ["kms:GenerateDataKey", "kms:Decrypt"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current[0].account_id]
    }
  }
}

resource "aws_sns_topic" "feedback" {
  count             = local.create_topic ? 1 : 0
  name              = "${local.resource_name_prefix}-ses-feedback"
  kms_master_key_id = local.create_kms_key ? aws_kms_key.feedback[0].key_id : var.kms_key_id
  tags              = var.tags
}

# SES doesn't inherit permission to publish just because the topic is in the
# same account (unlike CloudWatch alarm actions) — without this policy SES
# silently drops bounce/complaint events with no error at apply or send time.
data "aws_iam_policy_document" "feedback_topic_publish" {
  count = local.create_topic ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    resources = [aws_sns_topic.feedback[0].arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current[0].account_id]
    }
  }
}

resource "aws_sns_topic_policy" "feedback" {
  count  = local.create_topic ? 1 : 0
  arn    = aws_sns_topic.feedback[0].arn
  policy = data.aws_iam_policy_document.feedback_topic_publish[0].json
}

resource "aws_sns_topic_subscription" "feedback_email" {
  count     = var.feedback_notification_email != null ? 1 : 0
  topic_arn = local.topic_arn
  protocol  = "email"
  endpoint  = var.feedback_notification_email
}

resource "aws_ses_event_destination" "feedback" {
  count                  = local.create_config_set ? 1 : 0
  name                   = "${local.resource_name_prefix}-feedback"
  configuration_set_name = aws_ses_configuration_set.feedback[0].name
  enabled                = true
  matching_types         = ["bounce", "complaint"]

  sns_destination {
    topic_arn = local.topic_arn
  }
}
