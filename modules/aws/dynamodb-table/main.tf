# DynamoDB requires an `attribute` block for every attribute used as a hash/range key on the
# table itself OR on any global secondary index — never for a non-key attribute. Building one
# deduplicated map (keyed by attribute name) covers the table's own key plus every GSI's key,
# so a GSI reusing the table's own hash/range key doesn't produce a duplicate `attribute` block.
locals {
  table_key_attributes = merge(
    { (var.hash_key) = var.hash_key_type },
    var.range_key != "" ? { (var.range_key) = var.range_key_type } : {},
  )

  gsi_key_attributes = merge([
    for gsi in var.global_secondary_indexes : merge(
      { (gsi.hash_key) = gsi.hash_key_type },
      gsi.range_key != null ? { (gsi.range_key) = gsi.range_key_type } : {},
    )
  ]...)

  all_key_attributes = merge(local.table_key_attributes, local.gsi_key_attributes)
}

resource "aws_dynamodb_table" "primary" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key != "" ? var.range_key : null
  tags         = var.tags

  dynamic "attribute" {
    for_each = local.all_key_attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute != null ? [1] : []
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    }
  }

  # CP-9 / SC-28: point-in-time recovery and encryption at rest, always on.
  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}
