# ===========================================================================
# Ticket Switchboard - AI-powered IT help desk ticketing system.
#
# Wiring order (Terraform works this out from the references below):
#
#   dynamodb ─┬─► handler Lambda ─► api_gateway ─┐
#             │                                  ├─► index.html in S3
#   frontend ─┴─► cognito ────────────────────────┘
#             │
#   notifications ─► notifier Lambda ─► stream event source mapping
#
# Cognito needs the CloudFront URL as its callback, and index.html needs both
# the Cognito and API Gateway values - so the page upload lives in web_app.tf
# rather than inside the frontend module, which would create a cycle.
# ===========================================================================

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  table_name    = "${var.project_name}-tickets"
  handler_name  = "${var.project_name}-handler"
  notifier_name = "${var.project_name}-notifier"
  api_name      = "${var.project_name}-api"

  bucket_name = (
    var.bucket_name != ""
    ? var.bucket_name
    : "${var.project_name}-lab-${local.account_id}-${local.region}-${random_string.suffix.result}"
  )

  cognito_domain_prefix = (
    var.cognito_domain_prefix != ""
    ? var.cognito_domain_prefix
    : "${var.project_name}-${random_string.suffix.result}"
  )
}

# ---------------------------------------------------------------------------
# 1. Ticket store (lab section 6)
# ---------------------------------------------------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = local.table_name
  tags       = var.tags
}

# ---------------------------------------------------------------------------
# 2. Team notification channel (lab section 12)
# ---------------------------------------------------------------------------
module "notifications" {
  source = "./modules/notifications"

  name_prefix         = var.project_name
  display_name_prefix = var.app_display_name
  notification_email  = var.notification_email
  verify_ses_identity = var.verify_ses_identity
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# 3. Handler Lambda - Bedrock classification + DynamoDB write (section 7)
# ---------------------------------------------------------------------------
module "handler_lambda" {
  source = "./modules/lambda"

  function_name      = local.handler_name
  source_dir         = "${path.module}/lambda/handler"
  timeout            = 60 # Bedrock inference can take several seconds
  memory_size        = 256
  log_retention_days = var.log_retention_days

  environment = {
    TABLE_NAME          = module.dynamodb.table_name
    BEDROCK_MODEL_ID    = var.bedrock_model_id
    BEDROCK_MAX_TOKENS  = tostring(var.bedrock_max_tokens)
    BEDROCK_TEMPERATURE = tostring(var.bedrock_temperature)
    IT_STAFF_GROUP      = "it-staff"
    ALLOWED_ORIGIN      = "*"
  }

  policy_statements = {
    InvokeBedrockModel = {
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      resources = [
        "arn:${local.partition}:bedrock:${local.region}::foundation-model/${var.bedrock_model_id}",
        "arn:${local.partition}:bedrock:${local.region}:${local.account_id}:inference-profile/*",
      ]
    }
    TicketTableAccess = {
      actions = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      resources = [
        module.dynamodb.table_arn,
        "${module.dynamodb.table_arn}/index/*",
      ]
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 4. Front end hosting - S3 website + CloudFront (sections 9 and 10)
#    Created before Cognito, which needs the CloudFront URL as its callback.
# ---------------------------------------------------------------------------
module "frontend" {
  source = "./modules/frontend"

  bucket_name       = local.bucket_name
  distribution_name = "${var.project_name}-distribution"
  price_class       = var.cloudfront_price_class
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# 5. Authentication (sections 11 and 14)
# ---------------------------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"

  user_pool_name = "${var.project_name}-user-pool"
  name_prefix    = var.project_name
  domain_prefix  = local.cognito_domain_prefix
  callback_url   = module.frontend.app_url

  create_test_user   = var.create_test_user
  test_user_name     = var.test_user_name
  test_user_email    = var.notification_email
  test_user_password = var.test_user_password
  test_user_group    = var.test_user_group

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 6. REST API in front of the handler, secured by Cognito (sections 8 and 11)
# ---------------------------------------------------------------------------
module "api_gateway" {
  source = "./modules/api_gateway"

  api_name   = local.api_name
  stage_name = var.api_stage_name

  lambda_function_name  = module.handler_lambda.function_name
  lambda_invoke_arn     = module.handler_lambda.invoke_arn
  cognito_user_pool_arn = module.cognito.user_pool_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 7. Notifier Lambda - DynamoDB stream to SNS (section 13)
# ---------------------------------------------------------------------------
module "notifier_lambda" {
  source = "./modules/lambda"

  function_name      = local.notifier_name
  source_dir         = "${path.module}/lambda/notifier"
  timeout            = 30
  memory_size        = 128
  log_retention_days = var.log_retention_days

  environment = {
    TEAM_TOPICS  = jsonencode(module.notifications.team_topic_arns)
    DEFAULT_TEAM = "Support"
  }

  policy_statements = {
    ReadTicketStream = {
      actions = [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams",
      ]
      resources = [
        module.dynamodb.stream_arn,
        "${module.dynamodb.table_arn}/stream/*",
      ]
    }
    PublishToTeamTopics = {
      actions   = ["sns:Publish"]
      resources = module.notifications.topic_arn_list
    }
  }

  tags = var.tags
}

# The lab's "Add trigger" step: batch size 1, starting position LATEST.
resource "aws_lambda_event_source_mapping" "tickets_stream" {
  event_source_arn  = module.dynamodb.stream_arn
  function_name     = module.notifier_lambda.function_arn
  starting_position = "LATEST"
  batch_size        = 1
  enabled           = true
}
