# default_origin_id must name an entry in var.origins, and every other entry
# needs a path_pattern to be reachable — otherwise it's defined but unrouted.
# A plan-time warning, not a hard failure: Terraform 1.6 can't cross-reference
# variables in a variable validation block, and the resources below would
# just silently drop an unrouted origin rather than error either way.
check "origin_routing" {
  assert {
    condition     = contains([for o in var.origins : o.origin_id], var.default_origin_id)
    error_message = "default_origin_id '${var.default_origin_id}' does not match any entry in var.origins."
  }

  assert {
    condition     = alltrue([for o in var.origins : o.origin_id == var.default_origin_id || o.path_pattern != null])
    error_message = "every origin other than the default must set path_pattern, or it has no ordered_cache_behavior routing traffic to it."
  }
}

# Lets CloudFront sign requests to each origin: S3-type signs REST API calls to
# a private bucket, lambda-type signs calls to an AWS_IAM-only Function URL.
resource "aws_cloudfront_origin_access_control" "primary" {
  for_each = { for o in var.origins : o.origin_id => o }

  name                              = "${each.value.origin_id}-oac"
  origin_access_control_origin_type = each.value.origin_type == "s3" ? "s3" : "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "primary" {
  enabled             = true
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.aliases

  # Public edge must sit behind a WAF — required, no default. See
  # policy/aws/modules/cloudfront-distribution.rego for the plan-time check.
  web_acl_id = var.web_acl_arn

  dynamic "origin" {
    for_each = { for o in var.origins : o.origin_id => o }
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.value.origin_id
      origin_access_control_id = aws_cloudfront_origin_access_control.primary[origin.key].id

      # SC-8: HTTPS-only to Lambda Function URL origins, hardcoded.
      dynamic "custom_origin_config" {
        for_each = origin.value.origin_type == "lambda" ? [1] : []
        content {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id = var.default_origin_id

    allowed_methods = var.default_cache_behavior_allowed_methods
    cached_methods  = ["GET", "HEAD"]

    # Empty forwarded_headers/forwarded_query_string_keys/forwarded_cookie_names reproduce
    # this module's original hardcoded behavior (forward nothing) exactly, so existing
    # consumers are unaffected. Non-empty forwards and cache-keys on only those specific
    # headers/query-string-keys/cookie names — never "forward everything" on the default
    # behavior, which stays the ordered_cache_behavior's job below.
    forwarded_values {
      query_string            = length(var.forwarded_query_string_keys) > 0
      query_string_cache_keys = var.forwarded_query_string_keys
      headers                 = var.forwarded_headers

      cookies {
        forward           = length(var.forwarded_cookie_names) > 0 ? "whitelist" : "none"
        whitelisted_names = var.forwarded_cookie_names
      }
    }

    response_headers_policy_id = var.response_headers_policy_id

    # SC-8: no opt-out for plaintext HTTP to the viewer.
    viewer_protocol_policy = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for o in var.origins : o.origin_id => o if o.origin_id != var.default_origin_id && o.path_pattern != null }
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      target_origin_id = ordered_cache_behavior.value.origin_id

      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods  = ["GET", "HEAD"]

      forwarded_values {
        query_string = true
        cookies {
          forward = "all"
        }
      }

      response_headers_policy_id = var.response_headers_policy_id

      # SC-8: no opt-out for plaintext HTTP to the viewer.
      viewer_protocol_policy = "redirect-to-https"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = length(var.aliases) == 0 ? true : null
    acm_certificate_arn            = length(var.aliases) > 0 ? var.acm_certificate_arn : null
    ssl_support_method             = length(var.aliases) > 0 ? "sni-only" : null
    minimum_protocol_version       = length(var.aliases) > 0 ? "TLSv1.2_2021" : null
  }

  tags = var.tags
}

# AC-3: grants CloudFront read access to each S3 origin's bucket, scoped to
# this specific distribution via the SourceArn condition — the OAC bucket
# policy the s3-bucket module's README points here for.
resource "aws_s3_bucket_policy" "primary" {
  for_each = { for o in var.origins : o.origin_id => o if o.origin_type == "s3" }

  bucket = each.value.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${each.value.bucket_arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.primary.arn
        }
      }
    }]
  })
}

# AC-3: grants CloudFront's OAC-signed requests permission to invoke each
# Lambda origin's AWS_IAM-only Function URL, scoped to this distribution.
resource "aws_lambda_permission" "primary" {
  for_each = { for o in var.origins : o.origin_id => o if o.origin_type == "lambda" }

  statement_id           = "AllowCloudFrontInvokeFunctionUrl-${each.key}"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = each.value.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.primary.arn
  function_url_auth_type = "AWS_IAM"
}
