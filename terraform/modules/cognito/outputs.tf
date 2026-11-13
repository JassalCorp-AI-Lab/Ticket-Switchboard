output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN (used by the API Gateway authorizer)."
  value       = aws_cognito_user_pool.this.arn
}

output "spa_client_id" {
  description = "Client ID of the SPA app client, used by index.html."
  value       = aws_cognito_user_pool_client.spa.id
}

output "web_app_client_id" {
  description = "Client ID of the traditional web app client."
  value       = aws_cognito_user_pool_client.web_app.id
}

output "cognito_domain" {
  description = "Managed login base URL, with https:// and no trailing slash."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

output "hosted_ui_login_url" {
  description = "Direct link to the managed login page for the SPA client."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.spa.id}&response_type=code&scope=openid+email+phone&redirect_uri=${var.callback_url}"
}

output "group_names" {
  description = "Groups created in the pool."
  value       = [for g in aws_cognito_user_group.this : g.name]
}
