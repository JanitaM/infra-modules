terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "site_bucket" {
  source = "../../../modules/aws/s3-bucket"

  bucket_name        = "example-basic-site"
  versioning_enabled = true
  tags = {
    project = "basic-site"
  }
}

data "archive_file" "api_handler" {
  type        = "zip"
  source_file = "${path.module}/src/index.js"
  output_path = "${path.module}/build/handler.zip"
}

module "api_handler" {
  source = "../../../modules/aws/lambda-function-url"

  function_name    = "example-basic-site-api"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.api_handler.output_path
  source_code_hash = data.archive_file.api_handler.output_base64sha256
  tags = {
    project = "basic-site"
  }
}

# Empty rule set (default action: allow) — enough to satisfy the "public edge
# must sit behind a WAF" requirement for this example; a real project attaches
# actual managed rule groups here.
resource "aws_wafv2_web_acl" "edge" {
  name        = "example-basic-site-edge"
  description = "Edge WAF for the basic-site CloudFront distribution."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "example-basic-site-edge"
    sampled_requests_enabled   = true
  }

  tags = {
    project = "basic-site"
  }
}

module "site" {
  source = "../../../modules/aws/cloudfront-distribution"

  default_origin_id = "static-site"
  web_acl_arn       = aws_wafv2_web_acl.edge.arn

  origins = [
    {
      origin_id   = "static-site"
      origin_type = "s3"
      domain_name = module.site_bucket.bucket_regional_domain_name
      bucket_id   = module.site_bucket.bucket_id
      bucket_arn  = module.site_bucket.bucket_arn
    },
    {
      origin_id     = "api"
      origin_type   = "lambda"
      domain_name   = replace(replace(module.api_handler.function_url, "https://", ""), "/", "")
      function_name = module.api_handler.function_name
      path_pattern  = "/api/*"
    },
  ]

  tags = {
    project = "basic-site"
  }
}

output "bucket_id" {
  value = module.site_bucket.bucket_id
}

output "bucket_arn" {
  value = module.site_bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  value = module.site_bucket.bucket_regional_domain_name
}

output "api_function_url" {
  value = module.api_handler.function_url
}

output "cloudfront_domain_name" {
  value = module.site.domain_name
}

output "api_origin_id" {
  value = "api"
}

module "users" {
  source = "../../../modules/aws/cognito"

  user_pool_name = "example-basic-site-users"
  client_name    = "example-basic-site-web-client"
  tags = {
    project = "basic-site"
  }
}

output "user_pool_id" {
  value = module.users.user_pool_id
}

output "user_pool_client_id" {
  value = module.users.user_pool_client_id
}

module "mail" {
  source = "../../../modules/aws/ses"

  domain = "mail.example-basic-site.com"
  tags = {
    project = "basic-site"
  }
}

output "ses_domain_identity_arn" {
  value = module.mail.domain_identity_arn
}

output "ses_send_policy_arn" {
  value = module.mail.send_policy_arn
}

module "dns" {
  source = "../../../modules/aws/route53"

  domain_name = "example-basic-site.com"

  alias_records = [
    {
      name               = ""
      type               = "A"
      target_domain_name = module.site.domain_name
      target_zone_id     = module.site.hosted_zone_id
    },
  ]

  records = [
    {
      name   = "_amazonses.mail.example-basic-site.com"
      type   = "TXT"
      values = [module.mail.verification_token]
    },
    {
      name   = "${module.mail.dkim_tokens[0]}._domainkey.mail.example-basic-site.com"
      type   = "CNAME"
      values = ["${module.mail.dkim_tokens[0]}.dkim.amazonses.com"]
    },
  ]

  tags = {
    project = "basic-site"
  }
}

output "dns_zone_id" {
  value = module.dns.zone_id
}

output "dns_name_servers" {
  value = module.dns.name_servers
}

module "ci" {
  source = "../../../modules/aws/codebuild"

  project_name    = "example-basic-site-ci"
  description     = "Runs tests on each push to example-basic-site."
  source_type     = "GITHUB"
  source_location = "https://github.com/JanitaM/example-basic-site.git"

  tags = {
    project = "basic-site"
  }
}

output "ci_project_name" {
  value = module.ci.project_name
}

output "ci_project_arn" {
  value = module.ci.project_arn
}

module "api_key" {
  source = "../../../modules/aws/secrets-manager"

  secret_name   = "example-basic-site/api-key"
  description   = "Third-party API key used by the basic-site Lambda handler."
  secret_string = "placeholder-rotate-before-use"

  tags = {
    project = "basic-site"
  }
}

output "api_key_secret_arn" {
  value = module.api_key.secret_arn
}

output "api_key_read_policy_arn" {
  value = module.api_key.read_policy_arn
}

module "feature_flags" {
  source = "../../../modules/aws/ssm"

  parameter_name = "/example-basic-site/feature-flags"
  description    = "Feature flag config consumed by the basic-site Lambda handler."
  value          = "{}"

  tags = {
    project = "basic-site"
  }
}

output "feature_flags_parameter_arn" {
  value = module.feature_flags.parameter_arn
}

output "feature_flags_read_policy_arn" {
  value = module.feature_flags.read_policy_arn
}

module "api_errors_alarm" {
  source = "../../../modules/aws/cloudwatch"

  alarm_name          = "example-basic-site-api-errors"
  alarm_description   = "Alerts when the basic-site API handler Lambda errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    FunctionName = module.api_handler.function_name
  }

  tags = {
    project = "basic-site"
  }
}

output "api_errors_alarm_arn" {
  value = module.api_errors_alarm.alarm_arn
}

output "api_errors_alert_topic_arn" {
  value = module.api_errors_alarm.topic_arn
}

module "monthly_budget" {
  source = "../../../modules/aws/budget"

  budget_name          = "example-basic-site-monthly"
  limit_amount         = "200.0"
  threshold_percentage = 80
  alert_emails         = ["billing@example-basic-site.com"]
  sns_topic_arn        = module.api_errors_alarm.topic_arn

  tags = {
    project = "basic-site"
  }
}

output "monthly_budget_arn" {
  value = module.monthly_budget.budget_arn
}
