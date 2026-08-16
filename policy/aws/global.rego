package main

import rego.v1

# AWS-wide rules. Every provider's rules share the `main` package so a single
# `conftest test --policy policy/` run covers the whole set; rules are keyed on
# provider-specific resource types, so a GCP plan simply never matches these.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), not by module — an intent that spans multiple
# resource types (e.g. encryption at rest on both S3 and DynamoDB) gets one
# section here rather than being re-implemented per module. These rules check
# the plan itself, not just a module's defaults, so they also catch a
# resource someone writes by hand instead of through a module.

# Returns the module/resource path an address belongs to, with the
# resource type and name stripped off. Two resources in the same module
# instance (e.g. a bucket and its public access block) share this path.
module_path(addr) := path if {
  parts := split(addr, ".")
  n := count(parts)
  n >= 2
  path := concat(".", array.slice(parts, 0, n - 2))
}

# ---- Intent: object storage must not be publicly readable/writable ----

fully_blocked(block) if {
  block.change.after.block_public_acls == true
  block.change.after.block_public_policy == true
  block.change.after.ignore_public_acls == true
  block.change.after.restrict_public_buckets == true
}

deny contains msg if {
  bucket := input.resource_changes[_]
  bucket.type == "aws_s3_bucket"

  matching_blocks := [b |
    b := input.resource_changes[_]
    b.type == "aws_s3_bucket_public_access_block"
    module_path(b.address) == module_path(bucket.address)
    fully_blocked(b)
  ]

  count(matching_blocks) == 0

  msg := sprintf(
    "S3 bucket '%s' has no aws_s3_bucket_public_access_block blocking all public access. Buckets must never be public — see infra-overview.md CI/CD Pipeline policy gate.",
    [bucket.address],
  )
}

# ---- Intent: encryption at rest on stored data ----

deny contains msg if {
  bucket := input.resource_changes[_]
  bucket.type == "aws_s3_bucket"

  matching_encryption := [e |
    e := input.resource_changes[_]
    e.type == "aws_s3_bucket_server_side_encryption_configuration"
    module_path(e.address) == module_path(bucket.address)
  ]

  count(matching_encryption) == 0

  msg := sprintf(
    "S3 bucket '%s' has no server-side encryption configuration. Encryption at rest is required.",
    [bucket.address],
  )
}

dynamodb_sse_enabled(table) if {
  some s in table.change.after.server_side_encryption
  s.enabled == true
}

deny contains msg if {
  table := input.resource_changes[_]
  table.type == "aws_dynamodb_table"
  not dynamodb_sse_enabled(table)
  msg := sprintf(
    "DynamoDB table '%s' does not have server-side encryption enabled. Encryption at rest is required.",
    [table.address],
  )
}

# ---- Intent: point-in-time recovery on databases ----

dynamodb_pitr_enabled(table) if {
  some p in table.change.after.point_in_time_recovery
  p.enabled == true
}

deny contains msg if {
  table := input.resource_changes[_]
  table.type == "aws_dynamodb_table"
  not dynamodb_pitr_enabled(table)
  msg := sprintf(
    "DynamoDB table '%s' does not have point-in-time recovery enabled.",
    [table.address],
  )
}

# ---- Intent: no wildcard (*) IAM permissions ----

as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)

has_wildcard(x) if {
  some v in as_array(x)
  v == "*"
}

deny contains msg if {
  pol := input.resource_changes[_]
  pol.type in {"aws_iam_policy", "aws_iam_role_policy"}
  doc := json.unmarshal(pol.change.after.policy)
  some stmt in as_array(doc.Statement)
  stmt.Effect == "Allow"
  has_wildcard(stmt.Action)

  msg := sprintf(
    "IAM policy '%s' grants a wildcard (*) action. IAM permissions must not use wildcard actions or resources.",
    [pol.address],
  )
}

deny contains msg if {
  pol := input.resource_changes[_]
  pol.type in {"aws_iam_policy", "aws_iam_role_policy"}
  doc := json.unmarshal(pol.change.after.policy)
  some stmt in as_array(doc.Statement)
  stmt.Effect == "Allow"
  has_wildcard(stmt.Resource)

  msg := sprintf(
    "IAM policy '%s' grants access to a wildcard (*) resource. IAM permissions must not use wildcard actions or resources.",
    [pol.address],
  )
}
