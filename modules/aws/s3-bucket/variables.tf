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
