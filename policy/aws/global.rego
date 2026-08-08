package main

import rego.v1

# AWS-wide rules. Every provider's rules share the `main` package so a single
# `conftest test --policy policy/` run covers the whole set; rules are keyed on
# provider-specific resource types, so a GCP plan simply never matches these.

# Fails the build if any S3 bucket in the plan does not have a matching
# aws_s3_bucket_public_access_block resource blocking all four public-access
# settings. This checks the plan itself, not just the s3-bucket module's
# defaults, so it also catches a bucket someone writes by hand instead of
# through the module.

# Returns the module/resource path an address belongs to, with the
# resource type and name stripped off. Two resources in the same module
# instance (e.g. the bucket and its public access block) share this path.
module_path(addr) := path if {
  parts := split(addr, ".")
  n := count(parts)
  n >= 2
  path := concat(".", array.slice(parts, 0, n - 2))
}

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
