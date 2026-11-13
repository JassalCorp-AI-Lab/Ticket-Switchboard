output "app_url" {
  description = "Open this in a browser to use the app."
  value       = module.frontend.app_url
}

output "api_tickets_endpoint" {
  description = "API Gateway endpoint the front end calls."
  value       = module.api_gateway.tickets_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_spa_client_id" {
  description = "Client ID of the SPA client that index.html uses."
  value       = module.cognito.spa_client_id
}

output "cognito_domain" {
  description = "Managed login base URL."
  value       = module.cognito.cognito_domain
}

output "hosted_ui_login_url" {
  description = "Direct link to the Cognito managed login page."
  value       = module.cognito.hosted_ui_login_url
}

output "dynamodb_table_name" {
  description = "Name of the tickets table."
  value       = module.dynamodb.table_name
}

output "s3_bucket_name" {
  description = "Bucket hosting index.html."
  value       = module.frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.frontend.distribution_id
}

output "team_topic_arns" {
  description = "SNS topic ARN for each team."
  value       = module.notifications.team_topic_arns
}

output "lambda_functions" {
  description = "Both Lambda function names."
  value = {
    handler  = module.handler_lambda.function_name
    notifier = module.notifier_lambda.function_name
  }
}

output "test_user" {
  description = "Username of the seeded Cognito user, if one was created."
  value       = var.create_test_user ? var.test_user_name : null
}

output "next_steps" {
  description = "What still needs a human after apply finishes."
  value       = <<-EOT

    ${var.app_display_name} is deployed. Two things still need you:

    1. Confirm the email subscriptions
       AWS sent 5 "AWS Notification - Subscription Confirmation" emails to
       ${var.notification_email} (one per team topic) plus an SES verification
       mail. Click every link, including the ones in your spam folder.

    2. Sign in
       Open ${module.frontend.app_url} and click "Login with Cognito".
       User: ${var.test_user_name} / the temporary password from your tfvars.
       Cognito asks for a new permanent password at first sign-in.

    CloudFront can take 5-10 minutes to finish deploying worldwide. If the
    page 404s right after apply, wait and reload.

    Tickets are classified by "${var.bedrock_model_id}" on Amazon Bedrock.
    There is nothing to enable in the Bedrock console - serverless models are
    subscribed on first invocation. See README section 9 to use a different
    model.
  EOT
}
