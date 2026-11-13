# ---------------------------------------------------------------------------
# Static front end: public S3 website bucket behind a CloudFront distribution.
# Lab sections 9 and 10.
#
# The lab uses the S3 *website* endpoint as the CloudFront origin (not the
# REST endpoint), which is why the bucket has to allow public reads and why
# the origin is a custom HTTP origin - S3 website endpoints do not speak HTTPS.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read" {
  statement {
    sid     = "PublicReadGetObject"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.public_read.json

  # The policy is rejected until the public access block is lifted.
  depends_on = [aws_s3_bucket_public_access_block.site]
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.index_document
  }
}

# --- CloudFront -------------------------------------------------------------
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = var.distribution_name
  default_root_object = var.index_document
  price_class         = var.price_class

  origin {
    origin_id   = "s3-website-origin"
    domain_name = aws_s3_bucket_website_configuration.site.website_endpoint

    custom_origin_config {
      origin_protocol_policy = "http-only" # S3 website endpoints are HTTP only
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 30
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-website-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS managed policies: CachingOptimized + CORS-S3Origin.
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}
