# ---------------------------------------------------------------------------
# Required
# ---------------------------------------------------------------------------

variable "notification_email" {
  description = <<-EOT
    An email address you can open. It is verified in Amazon SES, subscribed to
    all five SNS team topics, and used for the Cognito test user. You will have
    to click the confirmation links AWS emails you after `apply`.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "notification_email must be a valid email address."
  }
}

variable "test_user_password" {
  description = <<-EOT
    Temporary password for the Cognito test user. Minimum 8 characters with
    upper case, lower case, a number and a symbol. Cognito forces a permanent
    password at first sign-in. Set it in terraform.tfvars or export
    TF_VAR_test_user_password.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.test_user_password) >= 8 &&
      can(regex("[a-z]", var.test_user_password)) &&
      can(regex("[A-Z]", var.test_user_password)) &&
      can(regex("[0-9]", var.test_user_password)) &&
      can(regex("[^a-zA-Z0-9]", var.test_user_password))
    )
    error_message = "test_user_password needs 8+ characters with upper case, lower case, a number and a symbol."
  }
}

# ---------------------------------------------------------------------------
# Optional
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "Region for every resource. The lab is written for us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = <<-EOT
    Lowercase, DNS-safe prefix used to name every resource. Also seeds the
    generated S3 bucket name and Cognito domain prefix, both of which must be
    globally unique.
  EOT
  type        = string
  default     = "ticket-switchboard"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.project_name)) && length(var.project_name) <= 24
    error_message = "project_name must be lowercase alphanumeric with hyphens, max 24 characters (S3 and Cognito name limits)."
  }
}

variable "app_display_name" {
  description = "Human-readable application name shown in the web UI and on SNS notification emails."
  type        = string
  default     = "Ticket Switchboard"
}

variable "bedrock_model_id" {
  description = <<-EOT
    Bedrock model invoked by the handler Lambda. The handler uses the Converse
    API, so any model that supports Converse in aws_region works here without
    a code change. Must be available for on-demand inference and not Legacy.
    See README section 9.
  EOT
  type        = string
  default     = "mistral.ministral-3-8b-instruct"
}

variable "bedrock_max_tokens" {
  description = "Maximum tokens the classifier may generate per ticket."
  type        = number
  default     = 500
}

variable "bedrock_temperature" {
  description = "Sampling temperature. Low values keep the JSON classification deterministic."
  type        = number
  default     = 0.1
}

variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "prod"
}

variable "cognito_domain_prefix" {
  description = <<-EOT
    Prefix for the Cognito managed login domain. Must be globally unique.
    Leave empty to append a generated suffix to project_name.
  EOT
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = <<-EOT
    Name of the S3 bucket hosting the front end. Must be globally unique.
    Leave empty to build one from project_name, the account ID and a suffix.
  EOT
  type        = string
  default     = ""
}

variable "test_user_name" {
  description = "Username of the seeded Cognito test user."
  type        = string
  default     = "testemployee"
}

variable "test_user_group" {
  description = "Group the test user joins. it-staff can also list tickets."
  type        = string
  default     = "it-staff"

  validation {
    condition     = contains(["employees", "it-staff"], var.test_user_group)
    error_message = "test_user_group must be employees or it-staff."
  }
}

variable "create_test_user" {
  description = "Create the seeded Cognito test user."
  type        = bool
  default     = true
}

variable "verify_ses_identity" {
  description = "Create the SES email identity for notification_email."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for both Lambda functions."
  type        = number
  default     = 7
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_100 is the cheapest."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default = {
    Project   = "Ticket-Switchboard"
    ManagedBy = "Terraform"
  }
}
