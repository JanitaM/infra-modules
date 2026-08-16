variable "domain_name" {
  description = "Domain name for the public hosted zone."
  type        = string
}

variable "alias_records" {
  description = "Alias records (A/AAAA) pointing at another AWS resource's DNS target, e.g. a CloudFront distribution's domain_name + hosted_zone_id."
  type = list(object({
    name                   = string
    type                   = string # "A" or "AAAA"
    target_domain_name     = string
    target_zone_id         = string
    evaluate_target_health = optional(bool, false)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.alias_records : contains(["A", "AAAA"], r.type)])
    error_message = "alias_records[*].type must be \"A\" or \"AAAA\"."
  }
}

variable "records" {
  description = "Plain DNS records (e.g. TXT/CNAME for domain or SES verification) with an explicit TTL."
  type = list(object({
    name   = string
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  default     = {}
}
