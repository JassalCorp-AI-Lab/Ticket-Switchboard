variable "user_pool_name" {
  description = "Name of the Cognito user pool."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for the app client names, e.g. ticket-switchboard gives -app and -web clients."
  type        = string
}

variable "domain_prefix" {
  description = "Globally unique prefix for the Cognito managed login domain."
  type        = string
}

variable "callback_url" {
  description = "CloudFront URL registered as the OAuth return / sign-out URL (no trailing slash)."
  type        = string
}

variable "groups" {
  description = "Groups created in the pool."
  type        = list(string)
  default     = ["employees", "it-staff"]
}

variable "test_user_name" {
  description = "Username of the seeded test user."
  type        = string
  default     = "testemployee"
}

variable "test_user_email" {
  description = "Email address of the seeded test user."
  type        = string
}

variable "test_user_password" {
  description = "Temporary password for the test user; Cognito forces a change at first sign-in."
  type        = string
  sensitive   = true
}

variable "test_user_group" {
  description = "Group the test user is added to."
  type        = string
  default     = "it-staff"
}

variable "create_test_user" {
  description = "Create the seeded test user."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the user pool."
  type        = map(string)
  default     = {}
}
