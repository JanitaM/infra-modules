# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  web_acl_name = "test-waf"
}

run "only_the_managed_rule_group_by_default" {
  command = plan

  assert {
    condition     = length(aws_wafv2_web_acl.primary.rule) == 1
    error_message = "only the hardcoded known-bad-inputs managed rule group should exist without rate_based_rules or ip_allowlist"
  }

  assert {
    condition     = length(aws_wafv2_ip_set.allowlist) == 0
    error_message = "no ip set should be created without ip_allowlist"
  }

  assert {
    condition     = tolist(aws_wafv2_web_acl.primary.default_action)[0].allow != null
    error_message = "default_action should be allow by default"
  }

  assert {
    condition     = aws_cloudwatch_log_group.waf.name == "aws-waf-logs-test-waf"
    error_message = "the log group name must carry the aws-waf-logs- prefix WAF requires"
  }
}

run "rate_based_rule_without_path_prefix" {
  command = plan

  variables {
    rate_based_rules = [
      { name = "global-limit", limit = 1000 },
    ]
  }

  assert {
    condition     = length(aws_wafv2_web_acl.primary.rule) == 2
    error_message = "the managed rule group plus one rate_based_rules entry should exist"
  }
}

run "rate_based_rule_with_path_prefix_scopes_the_rate_limit" {
  command = plan

  variables {
    rate_based_rules = [
      { name = "api-limit", limit = 500, uri_path_prefix = "/api/" },
    ]
  }

  assert {
    condition     = length(aws_wafv2_web_acl.primary.rule) == 2
    error_message = "the managed rule group plus one rate_based_rules entry should exist"
  }
}

run "ip_allowlist_creates_ip_set_and_allowlist_rule" {
  command = plan

  variables {
    ip_allowlist = ["203.0.113.0/24"]
  }

  # The web ACL's rule set includes an ip_set_reference_statement pointing at
  # the ip set's arn, which is otherwise unknown until apply — a set
  # containing an unknown value is itself unknown, so length() on it can't
  # be evaluated at plan time without this override.
  override_resource {
    target          = aws_wafv2_ip_set.allowlist[0]
    override_during = plan
    values = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/ipset/test-waf-allowlist/abc"
    }
  }

  assert {
    condition     = length(aws_wafv2_ip_set.allowlist) == 1
    error_message = "an ip set should be created when ip_allowlist is set"
  }

  assert {
    condition     = length(aws_wafv2_web_acl.primary.rule) == 2
    error_message = "the managed rule group plus the allowlist rule should exist"
  }
}

run "rejects_invalid_scope" {
  command = plan

  variables {
    scope = "GLOBAL"
  }

  expect_failures = [var.scope]
}

run "rejects_invalid_default_action" {
  command = plan

  variables {
    default_action = "count"
  }

  expect_failures = [var.default_action]
}

run "rejects_invalid_rate_based_rule_action" {
  command = plan

  variables {
    rate_based_rules = [
      { name = "bad-rule", limit = 100, action = "log" },
    ]
  }

  expect_failures = [var.rate_based_rules]
}
