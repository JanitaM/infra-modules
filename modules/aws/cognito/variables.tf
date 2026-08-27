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

variable "hosted_ui_domain_prefix" {
  type        = string
  description = "Prefix for this pool's Cognito-hosted domain (the resulting Hosted UI lives at https://<prefix>.auth.<region>.amazoncognito.com). Must be globally unique across all AWS accounts, lowercase, and DNS-label-safe. Null (the default) creates no domain at all, so the Hosted UI's authorize/token/logout endpoints simply don't exist — a consumer doing only SRP auth (no OAuth2/OIDC redirect flow) never needs this."
  default     = null
}

variable "callback_urls" {
  type        = list(string)
  description = "Allowed OAuth2 redirect URIs for the app client. A non-empty list turns on the authorization-code flow (allowed_oauth_flows_user_pool_client = true, allowed_oauth_flows = [\"code\"]) needed for a Hosted UI login; the empty default leaves the client SRP-only, matching this module's original behavior. Requires hosted_ui_domain_prefix to be set — AWS rejects an OAuth-enabled client with no domain on its pool."
  default     = []
}

variable "logout_urls" {
  type        = list(string)
  description = "Allowed post-logout redirect URIs for the Hosted UI's /logout endpoint. Only meaningful when callback_urls is set."
  default     = []
}

variable "allowed_oauth_scopes" {
  type        = list(string)
  description = "OAuth scopes granted to the app client's authorization-code flow. Only meaningful when callback_urls is set."
  default     = ["openid", "email", "profile"]
}

variable "refresh_token_rotation" {
  type = object({
    feature                    = string
    retry_grace_period_seconds = optional(number, 0)
  })
  description = "Refresh-token rotation for the app client: each redeemed refresh token is replaced with a new one, and reuse of an already-rotated-out token can be detected. `feature` must be \"ENABLED\" or \"DISABLED\". `null` (the default) omits the block entirely, matching this module's original behavior — refresh tokens stay static/reusable for their full validity, with no rotation to detect reuse against."
  default     = null

  validation {
    condition     = var.refresh_token_rotation == null || contains(["ENABLED", "DISABLED"], var.refresh_token_rotation.feature)
    error_message = "refresh_token_rotation.feature must be \"ENABLED\" or \"DISABLED\"."
  }
}
