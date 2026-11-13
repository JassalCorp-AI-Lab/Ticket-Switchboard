# ---------------------------------------------------------------------------
# Render index.html with the live endpoint values and upload it to the website
# bucket. This is the lab's "Update and upload index.html" step (section 14).
#
# It sits in the root module on purpose: it depends on frontend, cognito and
# api_gateway, while cognito already depends on frontend. Putting the upload
# inside the frontend module would make those two modules depend on each
# other and Terraform would refuse the graph.
# ---------------------------------------------------------------------------

locals {
  # The <h1> renders the first word unhighlighted and the rest in the brand
  # colour, e.g. "Ticket" + "Switchboard".
  app_name_words = split(" ", trimspace(var.app_display_name))
  app_name_lead  = local.app_name_words[0]
  app_name_tail  = join(" ", slice(local.app_name_words, 1, length(local.app_name_words)))

  index_html = templatefile("${path.module}/frontend/index.html.tftpl", {
    api_endpoint          = module.api_gateway.tickets_endpoint
    user_pool_id          = module.cognito.user_pool_id
    client_id             = module.cognito.spa_client_id
    cognito_domain        = module.cognito.cognito_domain
    redirect_uri          = module.frontend.app_url
    app_name              = var.app_display_name
    app_name_lead         = local.app_name_lead
    app_name_tail         = local.app_name_tail
    handler_function_name = module.handler_lambda.function_name
  })
}

resource "aws_s3_object" "index" {
  bucket        = module.frontend.bucket_name
  key           = "index.html"
  content       = local.index_html
  content_type  = "text/html; charset=utf-8"
  cache_control = "no-cache, max-age=0"
  etag          = md5(local.index_html)
}

# Re-rendering the page only changes the object; CloudFront would keep serving
# the cached copy until the TTL expires. Invalidate whenever the HTML changes.
resource "terraform_data" "invalidate_cache" {
  triggers_replace = [aws_s3_object.index.etag]

  provisioner "local-exec" {
    command    = "aws cloudfront create-invalidation --distribution-id ${module.frontend.distribution_id} --paths \"/*\" --region ${var.aws_region}"
    on_failure = continue # an invalidation failure should not fail the apply
  }
}
