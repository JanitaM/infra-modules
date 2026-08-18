# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  origins = [
    {
      origin_id   = "s3-origin"
      origin_type = "s3"
      domain_name = "bucket.s3.amazonaws.com"
      bucket_id   = "my-bucket"
      bucket_arn  = "arn:aws:s3:::my-bucket"
    },
  ]
  default_origin_id = "s3-origin"
  web_acl_arn       = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/example/abc"
}

run "single_default_origin_gets_no_ordered_behavior_or_lambda_permission" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_policy.primary) == 1
    error_message = "an S3 bucket policy should be created for the s3 origin"
  }

  assert {
    condition     = length(aws_lambda_permission.primary) == 0
    error_message = "no lambda permission should be created when there is no lambda origin"
  }
}

run "lambda_origin_with_path_pattern_gets_ordered_behavior_and_permission" {
  command = plan

  variables {
    origins = [
      {
        origin_id   = "s3-origin"
        origin_type = "s3"
        domain_name = "bucket.s3.amazonaws.com"
        bucket_id   = "my-bucket"
        bucket_arn  = "arn:aws:s3:::my-bucket"
      },
      {
        origin_id     = "lambda-origin"
        origin_type   = "lambda"
        domain_name   = "abc123.lambda-url.us-east-1.on.aws"
        function_name = "my-function"
        path_pattern  = "/api/*"
      },
    ]
  }

  assert {
    condition     = length(aws_lambda_permission.primary) == 1
    error_message = "a lambda permission should be created for the lambda origin"
  }

  assert {
    condition     = length(aws_s3_bucket_policy.primary) == 1
    error_message = "the s3 bucket policy count should be unaffected by adding a lambda origin"
  }
}

run "no_aliases_uses_default_certificate" {
  command = plan

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.viewer_certificate)[0].cloudfront_default_certificate == true
    error_message = "cloudfront_default_certificate should be true when aliases is empty"
  }
}

run "aliases_use_acm_certificate" {
  command = plan

  variables {
    aliases             = ["cdn.example.com"]
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.viewer_certificate)[0].ssl_support_method == "sni-only"
    error_message = "ssl_support_method should be sni-only when aliases is non-empty"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.viewer_certificate)[0].acm_certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
    error_message = "acm_certificate_arn should be set when aliases is non-empty"
  }
}

run "rejects_invalid_origin_type" {
  command = plan

  variables {
    origins = [
      {
        origin_id   = "bad-origin"
        origin_type = "gcs"
        domain_name = "bucket.storage.googleapis.com"
      },
    ]
    default_origin_id = "bad-origin"
  }

  expect_failures = [var.origins]
}

run "rejects_invalid_price_class" {
  command = plan

  variables {
    price_class = "PriceClass_Cheap"
  }

  expect_failures = [var.price_class]
}

run "no_forwarding_by_default_matches_original_hardcoded_behavior" {
  command = plan

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].query_string == false
    error_message = "query_string should default to false, matching this module's original hardcoded behavior"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].cookies[0].forward == "none"
    error_message = "cookie forwarding should default to none, matching this module's original hardcoded behavior"
  }

  assert {
    condition     = length(tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].headers) == 0
    error_message = "no headers should be forwarded by default"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].response_headers_policy_id == null
    error_message = "no response headers policy should be attached by default"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].allowed_methods == toset(["GET", "HEAD"])
    error_message = "allowed_methods should default to GET/HEAD only, matching this module's original hardcoded behavior"
  }
}

run "forwarding_config_reaches_the_default_cache_behavior" {
  command = plan

  variables {
    forwarded_headers           = ["rsc"]
    forwarded_query_string_keys = ["_rsc"]
    forwarded_cookie_names      = ["__prerender_bypass"]
    response_headers_policy_id  = "abc123"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].query_string == true
    error_message = "query_string should be true when forwarded_query_string_keys is non-empty"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].query_string_cache_keys == tolist(["_rsc"])
    error_message = "query_string_cache_keys should match var.forwarded_query_string_keys"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].headers == toset(["rsc"])
    error_message = "headers should match var.forwarded_headers"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].cookies[0].forward == "whitelist"
    error_message = "cookie forwarding should switch to whitelist when forwarded_cookie_names is non-empty"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].forwarded_values[0].cookies[0].whitelisted_names == toset(["__prerender_bypass"])
    error_message = "whitelisted_names should match var.forwarded_cookie_names"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].response_headers_policy_id == "abc123"
    error_message = "response_headers_policy_id should be attached to the default cache behavior"
  }
}

run "allowed_methods_override_reaches_the_default_cache_behavior" {
  command = plan

  variables {
    default_cache_behavior_allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].allowed_methods == toset(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"])
    error_message = "allowed_methods should match var.default_cache_behavior_allowed_methods"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.default_cache_behavior)[0].cached_methods == toset(["GET", "HEAD"])
    error_message = "cached_methods should stay hardcoded to GET/HEAD regardless of allowed_methods"
  }
}

run "rejects_invalid_default_cache_behavior_allowed_method" {
  command = plan

  variables {
    default_cache_behavior_allowed_methods = ["BOGUS"]
  }

  expect_failures = [var.default_cache_behavior_allowed_methods]
}

run "response_headers_policy_reaches_ordered_cache_behavior_too" {
  command = plan

  variables {
    origins = [
      {
        origin_id   = "s3-origin"
        origin_type = "s3"
        domain_name = "bucket.s3.amazonaws.com"
        bucket_id   = "my-bucket"
        bucket_arn  = "arn:aws:s3:::my-bucket"
      },
      {
        origin_id     = "lambda-origin"
        origin_type   = "lambda"
        domain_name   = "abc123.lambda-url.us-east-1.on.aws"
        function_name = "my-function"
        path_pattern  = "/api/*"
      },
    ]
    response_headers_policy_id = "abc123"
  }

  assert {
    condition     = tolist(aws_cloudfront_distribution.primary.ordered_cache_behavior)[0].response_headers_policy_id == "abc123"
    error_message = "response_headers_policy_id should be attached to ordered cache behaviors too"
  }
}
