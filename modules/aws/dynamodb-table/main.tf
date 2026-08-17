resource "aws_dynamodb_table" "primary" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key != "" ? var.range_key : null
  tags         = var.tags

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = var.range_key != "" ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
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
