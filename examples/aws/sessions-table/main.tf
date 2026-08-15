terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "sessions_table" {
  source = "../../../modules/aws/dynamodb-table"

  table_name = "example-sessions"
  hash_key   = "session_id"
  tags = {
    project = "sessions-table"
  }
}

output "table_id" {
  value = module.sessions_table.table_id
}

output "table_arn" {
  value = module.sessions_table.table_arn
}
