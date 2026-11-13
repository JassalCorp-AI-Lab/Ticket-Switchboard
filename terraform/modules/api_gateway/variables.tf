variable "api_name" {
  description = "Name of the REST API."
  type        = string
}

variable "description" {
  description = "API description."
  type        = string
  default     = "AI-powered IT help desk ticketing API"
}

variable "stage_name" {
  description = "Deployment stage name."
  type        = string
  default     = "prod"
}

variable "resource_path" {
  description = "Path part of the resource under the API root."
  type        = string
  default     = "tickets"
}

variable "lambda_function_name" {
  description = "Name of the backing Lambda function (for the invoke permission)."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the backing Lambda function."
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool backing the authorizer."
  type        = string
}

variable "cors_allow_origin" {
  description = "Value returned in Access-Control-Allow-Origin by the OPTIONS preflight."
  type        = string
  default     = "*"
}

variable "tags" {
  description = "Tags applied to the API and stage."
  type        = map(string)
  default     = {}
}
