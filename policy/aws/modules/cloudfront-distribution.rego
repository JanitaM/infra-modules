package main

import rego.v1

# cloudfront-distribution module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# public edge must sit behind a WAF — is specific to CloudFront distributions,
# so it lives here rather than in global.rego alongside the cross-resource
# intents (encryption, public storage) that recur across multiple resource
# types. Matches on the distribution resource alone, so it applies the same
# whether the plan has one origin or several.

# ---- Intent: public edge must sit behind a WAF ----

deny contains msg if {
  dist := input.resource_changes[_]
  dist.type == "aws_cloudfront_distribution"
  web_acl_id := object.get(dist.change.after, "web_acl_id", "")
  web_acl_id == ""

  msg := sprintf(
    "CloudFront distribution '%s' has no WAF web ACL attached. Public edges must sit behind a WAF — set web_acl_id (see modules/aws/cloudfront-distribution).",
    [dist.address],
  )
}
