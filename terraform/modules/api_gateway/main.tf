# ---------------------------------------------------------------------------
# Regional REST API: /tickets with POST + GET (Lambda proxy, Cognito-
# authorized) and an OPTIONS mock for the browser preflight.
# Lab sections 8 and 11.
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = var.description

  endpoint_configuration {
    types           = ["REGIONAL"]
    ip_address_type = "ipv4"
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "tickets" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.resource_path
}

# --- Cognito authorizer -----------------------------------------------------
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.api_name}-cognito"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# --- POST / GET: Lambda proxy, token required -------------------------------
locals {
  lambda_methods = toset(["POST", "GET"])
}

resource "aws_api_gateway_method" "lambda" {
  for_each      = local.lambda_methods
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.tickets.id
  http_method   = each.value
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda" {
  for_each                = local.lambda_methods
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.tickets.id
  http_method             = aws_api_gateway_method.lambda[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = var.lambda_invoke_arn
  timeout_milliseconds    = 29000
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/${var.resource_path}"
}

# --- OPTIONS: CORS preflight, no authorization ------------------------------
# Browsers send the preflight without an Authorization header, so this method
# must stay open or every cross-origin call from CloudFront fails.
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.tickets.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.tickets.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.tickets.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.tickets.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
  }

  depends_on = [aws_api_gateway_integration.options]
}

# --- CORS headers on gateway-generated errors -------------------------------
# Without these, a 401 from the authorizer reaches the browser as an opaque
# CORS failure instead of a readable status.
resource "aws_api_gateway_gateway_response" "cors" {
  for_each      = toset(["DEFAULT_4XX", "DEFAULT_5XX"])
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = each.value

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origin}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
  }
}

# --- Deployment + stage -----------------------------------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Force a redeployment whenever any method, integration or authorizer
  # changes - the lab's "Authorization changes take effect only after
  # redeployment" step, automated.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.tickets,
      aws_api_gateway_method.lambda,
      aws_api_gateway_integration.lambda,
      aws_api_gateway_method.options,
      aws_api_gateway_integration.options,
      aws_api_gateway_method_response.options,
      aws_api_gateway_integration_response.options,
      aws_api_gateway_authorizer.cognito,
      aws_api_gateway_gateway_response.cors,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
  tags          = var.tags
}
