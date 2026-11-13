output "table_name" {
  description = "Name of the tickets table."
  value       = aws_dynamodb_table.tickets.name
}

output "table_arn" {
  description = "ARN of the tickets table."
  value       = aws_dynamodb_table.tickets.arn
}

output "stream_arn" {
  description = "ARN of the table's DynamoDB stream (event source for the notifier)."
  value       = aws_dynamodb_table.tickets.stream_arn
}
