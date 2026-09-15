variable "bucket_name" {
  type        = string
  description = "Globally unique bucket name."
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable object versioning."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the bucket."
  default     = {}
}

variable "cors_rules" {
  type = list(object({
    allowed_origins = list(string)
    allowed_methods = list(string)
    allowed_headers = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number)
  }))
  description = "CORS rules for the bucket. Empty (the default) creates no CORS configuration, so the bucket rejects every cross-origin browser request."
  default     = []
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of an existing customer-managed KMS key to encrypt the bucket with. Leave null (the default) for SSE-S3 (AES256). The module never creates a key itself."
  default     = null
}

variable "object_lock_enabled" {
  type        = bool
  description = "Enable S3 Object Lock on the bucket. AWS only allows this at bucket creation — it cannot be added to an existing bucket via a later apply. Enabling this makes the bucket Object-Lock-capable only; the caller still attaches their own aws_s3_bucket_object_lock_configuration (retention mode/period) on this module's bucket_id output. Requires versioning_enabled = true — enforced in main.tf via a lifecycle precondition, not here, since a variable validation block can't reference another variable until Terraform 1.9 and this module targets >= 1.7."
  default     = false
}
