output "bucket_name" {
  description = "Name of the website bucket."
  value       = aws_s3_bucket.site.id
}

output "bucket_arn" {
  description = "ARN of the website bucket."
  value       = aws_s3_bucket.site.arn
}

output "website_endpoint" {
  description = "S3 static website endpoint used as the CloudFront origin."
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
}

output "distribution_id" {
  description = "CloudFront distribution ID (used to invalidate the cache)."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_domain_name" {
  description = "CloudFront domain name, e.g. d111111abcdef8.cloudfront.net."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "app_url" {
  description = "Public HTTPS URL of the front end (no trailing slash)."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}
