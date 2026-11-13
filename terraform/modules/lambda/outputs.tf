output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN used by API Gateway for the integration URI."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_name" {
  description = "Name of the execution role."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN of the execution role."
  value       = aws_iam_role.this.arn
}
