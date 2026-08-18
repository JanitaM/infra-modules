variable "domain_name" {
  type        = string
  description = "Primary domain name for the certificate."
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names covered by the certificate."
  default     = []
}

variable "validation_method" {
  type        = string
  description = "DNS or EMAIL. See policy/aws/modules/acm.rego — EMAIL requires a human to click an approval link and isn't auditable the way DNS validation is."
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "validation_method must be DNS or EMAIL."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the certificate."
  default     = {}
}
