variable "table_name" {
  description = "Name of the DynamoDB table that stores support tickets."
  type        = string
}

variable "tags" {
  description = "Tags applied to the table."
  type        = map(string)
  default     = {}
}
