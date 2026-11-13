variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "source_dir" {
  description = "Directory containing lambda_function.py; zipped at plan time."
  type        = string
}

variable "handler" {
  description = "Entry point, module.function."
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Function timeout in seconds."
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
  default     = 256
}

variable "environment" {
  description = "Environment variables for the function."
  type        = map(string)
  default     = {}
}

variable "policy_statements" {
  description = <<-EOT
    IAM statements added to the function's execution role, keyed by SID.
    Each entry: { actions = [...], resources = [...] }.
  EOT
  type = map(object({
    actions   = list(string)
    resources = list(string)
  }))
  default = {}
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the function."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
