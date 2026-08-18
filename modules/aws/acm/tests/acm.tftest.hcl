# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  domain_name = "example.com"
}

run "issues_certificate_with_defaults" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS"
    error_message = "validation_method should default to DNS"
  }

  assert {
    condition     = length(aws_acm_certificate.this.subject_alternative_names) == 0
    error_message = "subject_alternative_names should default to empty"
  }
}

run "accepts_subject_alternative_names" {
  command = plan

  variables {
    subject_alternative_names = ["www.example.com"]
  }

  assert {
    condition     = contains(aws_acm_certificate.this.subject_alternative_names, "www.example.com")
    error_message = "subject_alternative_names should be passed through"
  }
}

run "rejects_invalid_validation_method" {
  command = plan

  variables {
    validation_method = "PHONE"
  }

  expect_failures = [var.validation_method]
}
