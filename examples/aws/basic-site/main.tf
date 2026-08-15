terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
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

output "bucket_id" {
  value = module.site_bucket.bucket_id
}

output "bucket_arn" {
  value = module.site_bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  value = module.site_bucket.bucket_regional_domain_name
}
