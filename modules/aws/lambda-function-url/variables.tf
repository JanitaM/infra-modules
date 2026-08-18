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
      "nodejs20.x", "nodejs18.x",
      "python3.12", "python3.11",
    ], var.runtime)
    error_message = "runtime must be one of the currently supported nodejs20.x, nodejs18.x, python3.12, python3.11."
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
