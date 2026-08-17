data "aws_caller_identity" "current" {}

resource "aws_route53_zone" "primary" {
  name = var.domain_name
  tags = var.tags
}

# SC-20: DNSSEC signing requires an asymmetric KMS key that Route 53 can sign
# with. AWS requires this key to exist in us-east-1 regardless of which
# region the zone is operationally tied to — callers outside us-east-1 must
# pass an aliased provider for this module. See policy/aws/modules/route53.rego
# for the plan-time check.
data "aws_iam_policy_document" "dnssec_key" {
  statement {
    sid = "AllowAccountRootFullAccess"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "AllowRoute53DNSSECSigning"
    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }
    actions   = ["kms:DescribeKey", "kms:GetPublicKey", "kms:Sign"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid = "AllowRoute53DNSSECCreateGrant"
    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_kms_key" "dnssec" {
  description              = "DNSSEC signing key for the ${var.domain_name} Route 53 hosted zone."
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  policy                   = data.aws_iam_policy_document.dnssec_key.json
  tags                     = var.tags
}

resource "aws_route53_key_signing_key" "primary" {
  hosted_zone_id             = aws_route53_zone.primary.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                       = replace(var.domain_name, ".", "-")
}

resource "aws_route53_hosted_zone_dnssec" "primary" {
  hosted_zone_id = aws_route53_key_signing_key.primary.hosted_zone_id
  depends_on     = [aws_route53_key_signing_key.primary]
}

resource "aws_route53_record" "alias" {
  for_each = { for r in var.alias_records : "${r.name}-${r.type}" => r }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = each.value.target_domain_name
    zone_id                = each.value.target_zone_id
    evaluate_target_health = each.value.evaluate_target_health
  }
}

resource "aws_route53_record" "plain" {
  for_each = { for r in var.records : "${r.name}-${r.type}" => r }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
