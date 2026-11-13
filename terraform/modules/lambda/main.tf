# ---------------------------------------------------------------------------
# Reusable Python Lambda: source zip, execution role, scoped inline policy and
# an explicit log group (so `terraform destroy` removes the logs too).
#
# The lab attaches the AmazonBedrockFullAccess / AmazonDynamoDBFullAccess /
# AmazonSNSFullAccess managed policies. This module grants the same operations
# but scoped to the exact table, stream, topics and model that the lab uses.
# ---------------------------------------------------------------------------

data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.function_name}.zip"

  # Keep interpreter artefacts out of the deployment package - running the
  # tests against the handler would otherwise bake __pycache__ into the zip.
  excludes = [
    "__pycache__",
    "__pycache__/*",
    "*.pyc",
    "*.pyo",
  ]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "inline" {
  count = length(var.policy_statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid       = statement.key
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  count  = length(var.policy_statements) > 0 ? 1 : 0
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline[0].json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.this.arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.basic_execution,
  ]
}
