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

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/src/index.js"
  output_path = "${path.module}/build/handler.zip"
}

module "webhook_handler" {
  source = "../../../modules/aws/lambda-function-url"

  function_name    = "example-webhook-handler"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256
  tags = {
    project = "webhook-handler"
  }
}

output "function_arn" {
  value = module.webhook_handler.function_arn
}

output "function_url" {
  value = module.webhook_handler.function_url
}

output "role_arn" {
  value = module.webhook_handler.role_arn
}
