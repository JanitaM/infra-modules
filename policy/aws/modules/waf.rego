package main

import rego.v1

# waf module policy.
#
# Organized by security baseline intent, matching global.rego's convention.
# This intent — the web ACL must report CloudWatch metrics — is specific to
# WAFv2 web ACLs, so it lives here rather than in global.rego. The waf module
# itself always sets cloudwatch_metrics_enabled = true with no opt-out; this
# rule catches a hand-rolled aws_wafv2_web_acl (as examples/aws/basic-site
# used before adopting this module) that skips it.

# ---- Intent: web ACL must report CloudWatch metrics ----

deny contains msg if {
  acl := input.resource_changes[_]
  acl.type == "aws_wafv2_web_acl"
  visibility_config := object.get(acl.change.after, "visibility_config", [{}])
  cloudwatch_metrics_enabled := object.get(visibility_config[0], "cloudwatch_metrics_enabled", false)
  cloudwatch_metrics_enabled != true

  msg := sprintf(
    "WAFv2 web ACL '%s' does not have CloudWatch metrics enabled. Set visibility_config.cloudwatch_metrics_enabled = true (see modules/aws/waf).",
    [acl.address],
  )
}
