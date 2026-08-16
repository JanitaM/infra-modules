variable "parameter_name" {
  type        = string
  description = "Parameter name. SSM convention supports \"/\" as a path separator (e.g. \"/prod/db-password\")."
}

variable "description" {
  type        = string
  description = "Parameter description."
  default     = ""
}

variable "value" {
  type        = string
  description = "Parameter value."
  sensitive   = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID or ARN to encrypt the parameter with. Defaults to the AWS-managed alias/aws/ssm key when null."
  default     = null
}

variable "tier" {
  type        = string
  description = "Parameter tier."
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Advanced", "Intelligent-Tiering"], var.tier)
    error_message = "tier must be Standard, Advanced, or Intelligent-Tiering."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the parameter and its read policy."
  default     = {}
}
