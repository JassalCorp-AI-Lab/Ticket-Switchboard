variable "name_prefix" {
  description = "Prefix for the SNS topic names, e.g. ticket-switchboard."
  type        = string
}

variable "display_name_prefix" {
  description = "Prefix for the SNS display name, which email subscribers see as the sender."
  type        = string
  default     = "Ticket Switchboard"
}

variable "teams" {
  description = <<-EOT
    Teams the model may assign a ticket to. Must match the assigned_team values
    the classifier prompt allows. Each gets a topic named
    "<name_prefix>-<lowercased team>-team".
  EOT
  type        = list(string)
  default     = ["Support", "Dev", "Prod", "Ops", "Security"]
}

variable "notification_email" {
  description = "Email address subscribed to every team topic and verified in SES."
  type        = string
}

variable "verify_ses_identity" {
  description = "Create the SES email identity (sends a verification mail you must click)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the SNS topics."
  type        = map(string)
  default     = {}
}
