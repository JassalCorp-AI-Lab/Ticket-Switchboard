variable "bucket_name" {
  description = "Globally unique name of the S3 bucket hosting the front end."
  type        = string
}

variable "distribution_name" {
  description = "Comment/name shown on the CloudFront distribution."
  type        = string
  default     = "ticket-switchboard-distribution"
}

variable "index_document" {
  description = "Index document for S3 website hosting and the CloudFront default root object."
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 keeps lab cost lowest."
  type        = string
  default     = "PriceClass_100"
}

variable "force_destroy_bucket" {
  description = "Let `terraform destroy` empty the bucket before deleting it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the bucket and distribution."
  type        = map(string)
  default     = {}
}
