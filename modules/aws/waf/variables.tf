variable "web_acl_name" {
  type        = string
  description = "Name for the web ACL (and its IP set, if ip_allowlist is set)."
}

variable "scope" {
  type        = string
  description = "CLOUDFRONT (global, for a CloudFront distribution) or REGIONAL (an ALB, API Gateway, etc. in this provider's region)."
  default     = "CLOUDFRONT"

  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "scope must be CLOUDFRONT or REGIONAL."
  }
}

variable "default_action" {
  type        = string
  description = "Action taken on a request that doesn't match any rule."
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

variable "rate_based_rules" {
  type = list(object({
    name                  = string
    limit                 = number
    evaluation_window_sec = optional(number, 300)
    uri_path_prefix       = optional(string)
    action                = optional(string, "block")
  }))
  description = "Rate-based rules, evaluated in order after the IP allowlist rule (if any). limit is the max requests per evaluation_window_sec from a single IP; uri_path_prefix scopes the rule to matching request paths."
  default     = []

  validation {
    condition     = alltrue([for r in var.rate_based_rules : contains(["allow", "block", "count"], r.action)])
    error_message = "every rate_based_rules entry's action must be allow, block, or count."
  }
}

variable "ip_allowlist" {
  type        = list(string)
  description = "IPv4 CIDRs to allow; every other source is blocked, regardless of default_action. Leave null for no allowlist."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the web ACL and its IP set."
  default     = {}
}
