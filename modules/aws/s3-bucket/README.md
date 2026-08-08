# s3-bucket

A private S3 bucket: public access fully blocked, encryption at rest always on, versioning configurable.

This module has no input for making the bucket public. Buckets that need to be reachable from the internet stay private and get read access through CloudFront Origin Access Control instead — see the `cloudfront-distribution` module, which takes a bucket from this module as an input and attaches the OAC bucket policy.

## Usage

```hcl
module "images_bucket" {
  source      = "github.com/JanitaM/infra-modules//modules/aws/s3-bucket?ref=v1.0.0"
  bucket_name = "example-images"
  versioning_enabled = true
  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `bucket_name` | Globally unique bucket name | `string` | — (required) |
| `versioning_enabled` | Enable object versioning | `bool` | `true` |
| `tags` | Tags applied to the bucket | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name/ID |
| `bucket_arn` | Bucket ARN |
| `bucket_regional_domain_name` | Regional domain name, for use as a CloudFront origin |

## What this module always does, with no opt-out

- Blocks all public access (ACLs and bucket policies) at the bucket level
- Enables AES256 server-side encryption
