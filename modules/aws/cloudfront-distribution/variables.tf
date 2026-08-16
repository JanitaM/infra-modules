variable "origins" {
  type = list(object({
    origin_id     = string
    origin_type   = string           # "s3" or "lambda"
    domain_name   = string           # bucket_regional_domain_name, or the function URL's host
    bucket_id     = optional(string) # required when origin_type == "s3"
    bucket_arn    = optional(string) # required when origin_type == "s3"
    function_name = optional(string) # required when origin_type == "lambda"
    path_pattern  = optional(string) # required unless origin_id == var.default_origin_id
  }))
  description = "Origins to attach to the distribution. Exactly one must have origin_id == default_origin_id; every other origin needs path_pattern to be routable."

  validation {
    condition     = alltrue([for o in var.origins : contains(["s3", "lambda"], o.origin_type)])
    error_message = "every origin's origin_type must be s3 or lambda."
  }
}

variable "default_origin_id" {
  type        = string
  description = "origin_id of the origin used by the default (catch-all) cache behavior. Must match an entry in var.origins."
}

variable "web_acl_arn" {
  type        = string
  description = "ARN of the WAFv2 web ACL (scope CLOUDFRONT) to attach. Required — public edges must sit behind a WAF."
}

variable "default_root_object" {
  type        = string
  description = "Object returned for requests to the distribution's root URL."
  default     = "index.html"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class."
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "aliases" {
  type        = list(string)
  description = "Alternate domain names (CNAMEs) for the distribution. Leave empty to use the default *.cloudfront.net certificate."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN (in us-east-1) for the aliases above. Required when aliases is non-empty."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the distribution."
  default     = {}
}
