# ---------------------------------------------------------------------------
# Ticket store.
#
# On-demand billing (no capacity planning), ticket_id as the partition key and
# a NEW_IMAGE stream so the notifier Lambda can react to every INSERT without
# polling. Lab section 6 + "Enable DynamoDB Streams" in section 13.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "tickets" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticket_id"

  attribute {
    name = "ticket_id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  point_in_time_recovery {
    enabled = false # lab resource - keeps teardown clean and cost at zero
  }

  tags = var.tags
}
