# ---------------------------------------------------------------------------
# Notification fan-out: one SNS topic per team, each with an email
# subscription, plus the verified SES sender identity. Lab section 12.
#
# Both SES verification and SNS email subscriptions need a human to click a
# link in their inbox - Terraform can create them but cannot confirm them.
# ---------------------------------------------------------------------------

locals {
  # "Support" => "ticket-switchboard-support-team"
  team_topic_names = {
    for team in var.teams : team => "${var.name_prefix}-${lower(team)}-team"
  }
}

resource "aws_sns_topic" "team" {
  for_each = local.team_topic_names

  name = each.value

  # Email subscribers see this as the sender name; SNS caps it at 100 chars.
  display_name = substr("${var.display_name_prefix} ${each.key}", 0, 100)

  tags = var.tags
}

resource "aws_sns_topic_subscription" "team_email" {
  for_each = aws_sns_topic.team

  topic_arn = each.value.arn
  protocol  = "email"
  endpoint  = var.notification_email

  # SNS reports an email subscription as "pending confirmation" until the
  # recipient clicks the link, and never hands back a real subscription ARN.
  lifecycle {
    ignore_changes = [endpoint]
  }
}

resource "aws_sesv2_email_identity" "sender" {
  count = var.verify_ses_identity ? 1 : 0

  email_identity = var.notification_email
  tags           = var.tags
}
