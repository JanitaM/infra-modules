# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  bucket_name = "test-bucket"
}

run "no_cors_configuration_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.primary) == 0
    error_message = "no aws_s3_bucket_cors_configuration should be planned when cors_rules is empty"
  }
}

run "cors_rule_creates_cors_configuration" {
  command = plan

  variables {
    cors_rules = [{
      allowed_origins = ["https://app.example.com"]
      allowed_methods = ["GET", "PUT"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
    }]
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.primary) == 1
    error_message = "one aws_s3_bucket_cors_configuration should be planned when cors_rules is non-empty"
  }

  assert {
    condition     = length(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)) == 1
    error_message = "one cors_rule block should be planned per cors_rules list entry"
  }

  assert {
    condition     = contains(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)[0].allowed_origins, "https://app.example.com")
    error_message = "cors_rule's allowed_origins should match the input variable"
  }
}

run "multiple_cors_rules_create_multiple_blocks" {
  command = plan

  variables {
    cors_rules = [
      {
        allowed_origins = ["https://app.example.com"]
        allowed_methods = ["GET", "PUT"]
        allowed_headers = ["*"]
      },
      {
        allowed_origins = ["https://other.example.com"]
        allowed_methods = ["GET"]
        allowed_headers = ["*"]
      },
    ]
  }

  assert {
    condition     = length(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)) == 2
    error_message = "one cors_rule block should be planned per cors_rules list entry"
  }
}
