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

variable "default_cache_behavior_allowed_methods" {
  type        = list(string)
  description = "HTTP methods allowed on the default cache behavior. Defaults to GET/HEAD only, matching this module's original hardcoded behavior."
  default     = ["GET", "HEAD"]

  validation {
    condition = alltrue([
      for m in var.default_cache_behavior_allowed_methods :
      contains(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"], m)
    ])
    error_message = "default_cache_behavior_allowed_methods may only contain GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE."
  }
}

variable "forwarded_headers" {
  type        = list(string)
  description = "Request headers to forward to the origin and include in the default cache behavior's cache key. Leave empty to forward none, matching CloudFront's own default."
  default     = []
}

variable "forwarded_query_string_keys" {
  type        = list(string)
  description = "Query string keys to forward to the origin and include in the default cache behavior's cache key. Leave empty to forward no query strings at all — non-empty does not mean 'forward everything', only these specific keys."
  default     = []
}

variable "forwarded_cookie_names" {
  type        = list(string)
  description = "Cookie names to forward to the origin and include in the default cache behavior's cache key. Leave empty to forward no cookies at all."
  default     = []
}

variable "cache_policy_id" {
  type        = string
  description = "ID of an aws_cloudfront_cache_policy to attach to every cache behavior, replacing the legacy forwarded_values block (and its implicit TTL defaults) entirely. Mutually exclusive with forwarded_headers/forwarded_query_string_keys/forwarded_cookie_names. This module does not author the policy itself. Leave null to keep the module's original forwarded_values-based behavior."
  default     = null
}

variable "origin_request_policy_id" {
  type        = string
  description = "ID of an aws_cloudfront_origin_request_policy to attach to every cache behavior. Only meaningful alongside cache_policy_id. Leave null to attach none."
  default     = null
}

variable "response_headers_policy_id" {
  type        = string
  description = "ID of an aws_cloudfront_response_headers_policy to attach to every cache behavior (e.g. for CSP/HSTS/X-Frame-Options). This module does not author the policy itself — header content is inherently project-specific. Leave null to attach none."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the distribution."
  default     = {}
}
