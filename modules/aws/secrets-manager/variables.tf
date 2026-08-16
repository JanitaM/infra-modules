variable "secret_name" {
  type        = string
  description = "Secret name. Secrets Manager convention supports \"/\" as a path separator (e.g. \"prod/db-password\")."
}

variable "description" {
  type        = string
  description = "Secret description."
  default     = ""
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID or ARN to encrypt the secret with. Defaults to the AWS-managed aws/secretsmanager key when null."
  default     = null
}

variable "secret_string" {
  type        = string
  description = "Initial secret value. Leave null to create the secret container without a version (e.g. when a separate process populates it)."
  default     = null
  sensitive   = true
}

variable "recovery_window_in_days" {
  type        = number
  description = "Days AWS retains a deleted secret for recovery before permanent deletion. Must be 0 (immediate deletion, no recovery) or 7-30."
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "resource_policy_json" {
  type        = string
  description = "IAM resource policy JSON to attach to the secret, e.g. for cross-account access. Leave null for no resource policy (default: private, reachable only via the caller's own IAM). Must not grant a wildcard principal — see policy/aws/modules/secrets-manager.rego."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the secret and its read policy."
  default     = {}
}
