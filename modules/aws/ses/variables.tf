variable "domain" {
  type        = string
  description = "Domain to verify as an SES identity, e.g. mail.example.com. DNS records for verification and DKIM must be added separately (see outputs)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the sending IAM policy."
  default     = {}
}
