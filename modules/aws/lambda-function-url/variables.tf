variable "function_name" {
  type        = string
  description = "Lambda function name."
}

variable "handler" {
  type        = string
  description = "Function entrypoint, e.g. index.handler."
}

variable "runtime" {
  type        = string
  description = "Lambda runtime identifier."
  validation {
    condition = contains([
      "nodejs22.x", "nodejs20.x", "nodejs18.x",
      "python3.12", "python3.11",
    ], var.runtime)
    error_message = "runtime must be one of the currently supported nodejs22.x, nodejs20.x, nodejs18.x, python3.12, python3.11."
  }
}

variable "filename" {
  type        = string
  description = "Path to the deployment package (.zip) for the function."
}

variable "source_code_hash" {
  type        = string
  description = "Base64-encoded SHA256 of the deployment package, used to detect code changes. Required to make filename-based deploys apply reliably."
  default     = null
}

variable "timeout" {
  type        = number
  description = "Function timeout, in seconds."
  default     = 3
}

variable "memory_size" {
  type        = number
  description = "Function memory, in MB."
  default     = 128
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables passed to the function."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the function and its execution role."
  default     = {}
}

variable "additional_policy_arns" {
  type        = list(string)
  description = "ARNs of existing policies to attach to this function's execution role, in addition to the CloudWatch Logs baseline — e.g. the read_policy_arn/send_policy_arn output of another module in this repo."
  default     = []
}

variable "layers" {
  type        = list(string)
  description = "ARNs of Lambda layers to attach, e.g. a published extension layer (X-Ray, a monitoring agent, the AWS Lambda Web Adapter). Up to 5, matching Lambda's own limit."
  default     = []

  validation {
    condition     = length(var.layers) <= 5
    error_message = "layers may contain at most 5 entries — AWS Lambda's own per-function limit."
  }
}

variable "invoke_mode" {
  type        = string
  description = "Function URL invoke mode. BUFFERED (the default) returns the full response only once the function finishes. RESPONSE_STREAM delivers the response progressively as the function writes it — required for a proxied app (e.g. via the Lambda Web Adapter) that itself streams a response, such as a Next.js app using React Server Components streaming; setting an adapter's own streaming env var alone does not enable this at the Function URL level."
  default     = "BUFFERED"

  validation {
    condition     = contains(["BUFFERED", "RESPONSE_STREAM"], var.invoke_mode)
    error_message = "invoke_mode must be BUFFERED or RESPONSE_STREAM."
  }
}

variable "publish" {
  type        = bool
  description = "Publish a new immutable Lambda version on every apply that changes the function. Defaults to false, matching this module's original behavior (only $LATEST exists, no version history). Set true to enable alias-based rollback: each apply gets its own version number, and alias_name is repointed at the new one."
  default     = false
}

variable "alias_name" {
  type        = string
  description = "Name of the alias this module creates to track the version published on each apply. Only created when publish is true — it has nothing to point at otherwise."
  default     = "live"
}

variable "qualifier" {
  type        = string
  description = "Qualifier (alias name or version number) the Function URL invokes. null (the default) invokes $LATEST, matching this module's original behavior. Set to alias_name's value once publish is true to make the Function URL follow the alias instead of always tracking the newest code — that's what makes an alias repoint (without an apply) actually change what's served. Enforced via a resource precondition in main.tf rather than a variable validation block, since checking it against var.publish needs a cross-variable reference (Terraform >= 1.9) and this module's required_version floor is 1.7."
  default     = null
}
