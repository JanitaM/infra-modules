# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# aws_iam_policy_document is normally computed locally by the provider, not
# fetched from a real API — mock_provider mocks it too, so it needs an
# explicit override or its json output comes back invalid.
mock_provider "aws" {
  override_data {
    target = data.aws_iam_policy_document.dnssec_key
    values = {
      json = "{}"
    }
  }
}

variables {
  domain_name = "example.com"
}

run "no_records_by_default" {
  command = plan

  assert {
    condition     = length(aws_route53_record.alias) == 0
    error_message = "no alias records should be created when alias_records is empty"
  }

  assert {
    condition     = length(aws_route53_record.plain) == 0
    error_message = "no plain records should be created when records is empty"
  }
}

run "alias_record_created_when_set" {
  command = plan

  variables {
    alias_records = [
      {
        name               = "www.example.com"
        type               = "A"
        target_domain_name = "d123.cloudfront.net"
        target_zone_id     = "Z2FDTNDATAQYW2"
      },
    ]
  }

  assert {
    condition     = length(aws_route53_record.alias) == 1
    error_message = "one alias record should be created per entry in alias_records"
  }
}

run "plain_record_created_when_set" {
  command = plan

  variables {
    records = [
      {
        name   = "_verification.example.com"
        type   = "TXT"
        values = ["some-verification-token"]
      },
    ]
  }

  assert {
    condition     = length(aws_route53_record.plain) == 1
    error_message = "one plain record should be created per entry in records"
  }
}

run "rejects_invalid_alias_record_type" {
  command = plan

  variables {
    alias_records = [
      {
        name               = "www.example.com"
        type               = "CNAME"
        target_domain_name = "d123.cloudfront.net"
        target_zone_id     = "Z2FDTNDATAQYW2"
      },
    ]
  }

  expect_failures = [var.alias_records]
}
