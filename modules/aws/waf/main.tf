locals {
  ip_allowlist_enabled = var.ip_allowlist != null
}

resource "aws_wafv2_ip_set" "allowlist" {
  count = local.ip_allowlist_enabled ? 1 : 0

  name               = "${var.web_acl_name}-allowlist"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.ip_allowlist
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "primary" {
  name  = var.web_acl_name
  scope = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # Priority 0, always evaluated first: enforced independent of
  # default_action, so an allowlist can't be bypassed by a permissive default.
  dynamic "rule" {
    for_each = local.ip_allowlist_enabled ? [1] : []
    content {
      name     = "${var.web_acl_name}-ip-allowlist"
      priority = 0

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.allowlist[0].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${var.web_acl_name}-ip-allowlist"
      }
    }
  }

  # Priority 1: AWS-managed rule group covering known-bad-inputs patterns,
  # including the Log4Shell (CVE-2021-44228) request signatures. Hardcoded,
  # no opt-out.
  rule {
    name     = "${var.web_acl_name}-known-bad-inputs"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${var.web_acl_name}-known-bad-inputs"
    }
  }

  dynamic "rule" {
    for_each = { for idx, r in var.rate_based_rules : r.name => merge(r, { priority = idx + 2 }) }
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit                 = rule.value.limit
          aggregate_key_type    = "IP"
          evaluation_window_sec = rule.value.evaluation_window_sec

          dynamic "scope_down_statement" {
            for_each = rule.value.uri_path_prefix != null ? [1] : []
            content {
              byte_match_statement {
                search_string         = rule.value.uri_path_prefix
                positional_constraint = "STARTS_WITH"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = rule.value.name
      }
    }
  }

  # No opt-out: every web ACL and rule always reports CloudWatch metrics. See
  # policy/aws/modules/waf.rego for the plan-time check.
  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = var.web_acl_name
  }

  tags = var.tags
}

# WAF only accepts CloudWatch Logs destinations named with this exact prefix
# — AWS grants the WAF service write access to it implicitly, no resource
# policy needed. No opt-out: every web ACL always logs.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.web_acl_name}"
  retention_in_days = 90
  tags              = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "primary" {
  resource_arn            = aws_wafv2_web_acl.primary.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
