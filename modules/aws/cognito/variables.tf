variable "user_pool_name" {
  type        = string
  description = "Name of the Cognito user pool."
}

variable "client_name" {
  type        = string
  description = "Name of the user pool client (app client) created against the pool."
  default     = "app-client"
}

variable "auto_verified_attributes" {
  type        = list(string)
  description = "Attributes Cognito auto-verifies (and can use for account recovery). Each entry must be email or phone_number."
  default     = ["email"]

  validation {
    condition     = alltrue([for a in var.auto_verified_attributes : contains(["email", "phone_number"], a)])
    error_message = "auto_verified_attributes entries must be email or phone_number."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the user pool."
  default     = {}
}
