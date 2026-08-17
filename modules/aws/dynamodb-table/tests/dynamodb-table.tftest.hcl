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
