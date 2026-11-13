output "rest_api_id" {
  description = "ID of the REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  description = "Base invoke URL of the deployed stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "tickets_endpoint" {
  description = "Full URL of the /tickets resource, used by index.html."
  value       = "${aws_api_gateway_stage.this.invoke_url}/${var.resource_path}"
}
