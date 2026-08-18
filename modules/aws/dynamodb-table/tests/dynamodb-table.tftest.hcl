# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  table_name = "test-table"
  hash_key   = "id"
}

run "hash_key_only_by_default" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.primary.range_key == null
    error_message = "range_key should be null when var.range_key is empty"
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.attribute) == 1
    error_message = "only the hash key attribute should be declared when range_key is empty"
  }
}

run "range_key_adds_second_attribute" {
  command = plan

  variables {
    range_key = "created_at"
  }

  assert {
    condition     = aws_dynamodb_table.primary.range_key == "created_at"
    error_message = "range_key should be set when var.range_key is non-empty"
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.attribute) == 2
    error_message = "both hash key and range key attributes should be declared when range_key is set"
  }
}

run "rejects_invalid_billing_mode" {
  command = plan

  variables {
    billing_mode = "RESERVED"
  }

  expect_failures = [var.billing_mode]
}

run "no_gsi_by_default" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.primary.global_secondary_index) == 0
    error_message = "no global_secondary_index block should exist when global_secondary_indexes is empty"
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.ttl) == 0
    error_message = "no ttl block should exist when ttl_attribute is null"
  }
}

run "gsi_with_new_keys_adds_their_attributes" {
  command = plan

  variables {
    range_key = "created_at"
    global_secondary_indexes = [
      { name = "status-index", hash_key = "status", range_key = "published_at" },
    ]
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.global_secondary_index) == 1
    error_message = "one global_secondary_index block should exist"
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.attribute) == 4
    error_message = "hash_key, range_key, and the GSI's two new keys should each get one attribute block"
  }

  assert {
    condition     = tolist(aws_dynamodb_table.primary.global_secondary_index)[0].projection_type == "ALL"
    error_message = "projection_type should default to ALL"
  }
}

run "gsi_reusing_the_table_hash_key_does_not_duplicate_its_attribute" {
  command = plan

  variables {
    global_secondary_indexes = [
      { name = "reverse-index", hash_key = "id" },
    ]
  }

  assert {
    condition     = length(aws_dynamodb_table.primary.attribute) == 1
    error_message = "a GSI reusing the table's own hash key should not produce a second attribute block for it"
  }
}

run "ttl_attribute_adds_ttl_block" {
  command = plan

  variables {
    ttl_attribute = "expires_at"
  }

  assert {
    condition     = tolist(aws_dynamodb_table.primary.ttl)[0].attribute_name == "expires_at"
    error_message = "ttl block's attribute_name should match var.ttl_attribute"
  }

  assert {
    condition     = tolist(aws_dynamodb_table.primary.ttl)[0].enabled == true
    error_message = "ttl block should be enabled"
  }
}

run "rejects_invalid_gsi_projection_type" {
  command = plan

  variables {
    global_secondary_indexes = [
      { name = "bad-index", hash_key = "status", projection_type = "INCLUDE" },
    ]
  }

  expect_failures = [var.global_secondary_indexes]
}
