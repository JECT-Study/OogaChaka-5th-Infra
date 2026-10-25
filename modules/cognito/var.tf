variable "user_pool_name" {
  type = string
}

variable "client_name" {
  type = string
}

variable "domain_prefix" {
  type        = string
  default     = null
  description = "Hosted UI 도메인 접두사. null 이면 도메인을 만들지 않음"
}

variable "callback_urls" {
  type        = list(string)
  default     = []
  description = "로그인 후 redirect URL. 비워두면 Hosted UI(OAuth) 비활성화"
}

variable "logout_urls" {
  type    = list(string)
  default = []
}

variable "generate_secret" {
  type        = bool
  default     = false
  description = "서버(백엔드)에서만 쓰는 클라이언트면 true, SPA/모바일이면 false"
}

variable "explicit_auth_flows" {
  type    = list(string)
  default = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

variable "allow_admin_create_user_only" {
  type        = bool
  default     = false
  description = "true 면 관리자만 사용자 생성 가능 (회원가입 비활성화)"
}

variable "password_minimum_length" {
  type    = number
  default = 8
}

variable "password_require_symbols" {
  type    = bool
  default = false
}

variable "access_token_validity_hours" {
  type    = number
  default = 1
}

variable "id_token_validity_hours" {
  type    = number
  default = 1
}

variable "refresh_token_validity_days" {
  type    = number
  default = 30
}
