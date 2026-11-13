# ---------------------------------------------------------------------------
# Authentication: user pool, managed login domain + branding, the two app
# clients from the lab, the employees / it-staff groups and a test user.
# Lab sections 11 and 14.
# ---------------------------------------------------------------------------

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  # "Email and Username" sign-in identifiers: the username is the primary
  # identifier and email works as an alias.
  alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]

  # Self-registration enabled (lab setting).
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Off so `terraform destroy` can remove the pool without a console step.
  deletion_protection = "INACTIVE"

  tags = var.tags
}

# --- Managed login ----------------------------------------------------------
resource "aws_cognito_user_pool_domain" "this" {
  domain                = var.domain_prefix
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2 # 2 = managed login (the new branded pages)
}

locals {
  oauth_scopes  = ["openid", "email", "phone"]
  callback_urls = [var.callback_url]
}

# --- App clients ------------------------------------------------------------
# "<prefix>-app": traditional web application (confidential client, has a
# secret). Created by the lab's "Define your application" step.
resource "aws_cognito_user_pool_client" "web_app" {
  name         = "${var.name_prefix}-app"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = true

  callback_urls = local.callback_urls
  logout_urls   = local.callback_urls

  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = local.oauth_scopes

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# "<prefix>-web": single-page application. No client secret - this is the
# client ID that index.html uses with the PKCE authorization-code flow.
resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.name_prefix}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  callback_urls = local.callback_urls
  logout_urls   = local.callback_urls

  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = local.oauth_scopes

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# A managed login style must exist before the hosted pages render for the
# client - the lab's "Create a managed login style" step.
resource "aws_cognito_managed_login_branding" "spa" {
  client_id                   = aws_cognito_user_pool_client.spa.id
  user_pool_id                = aws_cognito_user_pool.this.id
  use_cognito_provided_values = true

  depends_on = [aws_cognito_user_pool_domain.this]
}

# --- Groups -----------------------------------------------------------------
# Names must match exactly: the handler Lambda checks for 'it-staff' in the
# cognito:groups claim.
resource "aws_cognito_user_group" "this" {
  for_each     = toset(var.groups)
  name         = each.value
  user_pool_id = aws_cognito_user_pool.this.id
}

# --- Test user --------------------------------------------------------------
resource "aws_cognito_user" "test" {
  count = var.create_test_user ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this.id
  username     = var.test_user_name

  attributes = {
    email          = var.test_user_email
    email_verified = true
  }

  temporary_password = var.test_user_password
  message_action     = "SUPPRESS" # "Don't send an invitation" in the lab

  lifecycle {
    # Cognito clears the temporary password once the user sets a permanent
    # one; without this, every later apply would try to reset it.
    ignore_changes = [temporary_password]
  }
}

resource "aws_cognito_user_in_group" "test" {
  count = var.create_test_user ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this.id
  username     = aws_cognito_user.test[0].username
  group_name   = aws_cognito_user_group.this[var.test_user_group].name
}
