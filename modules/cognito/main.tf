resource "aws_cognito_user_pool" "user_pool" {
  name = var.user_pool_name

  # 이메일을 로그인 ID 로 사용
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = var.password_minimum_length
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = var.password_require_symbols
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = var.allow_admin_create_user_only
  }

  tags = {
    Name = var.user_pool_name
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.user_pool.id

  generate_secret = var.generate_secret

  explicit_auth_flows = var.explicit_auth_flows

  # Hosted UI (OAuth2 authorization code flow) 는 callback_urls 를 넣었을 때만 활성화
  allowed_oauth_flows_user_pool_client = length(var.callback_urls) > 0
  allowed_oauth_flows                  = length(var.callback_urls) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(var.callback_urls) > 0 ? ["openid", "email", "profile"] : []
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = var.access_token_validity_hours
  id_token_validity      = var.id_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Hosted UI 도메인 (domain_prefix 를 넣었을 때만 생성)
resource "aws_cognito_user_pool_domain" "domain" {
  count = var.domain_prefix != null ? 1 : 0

  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.user_pool.id
}
