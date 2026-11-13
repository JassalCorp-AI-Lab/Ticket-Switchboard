output "team_topic_arns" {
  description = "Map of team name to SNS topic ARN, injected into the notifier Lambda."
  value       = { for team, topic in aws_sns_topic.team : team => topic.arn }
}

output "topic_arn_list" {
  description = "Flat list of topic ARNs, used to scope the notifier's sns:Publish permission."
  value       = [for topic in aws_sns_topic.team : topic.arn]
}

output "ses_identity" {
  description = "The SES email identity created for this lab, if enabled."
  value       = var.verify_ses_identity ? aws_sesv2_email_identity.sender[0].email_identity : null
}
