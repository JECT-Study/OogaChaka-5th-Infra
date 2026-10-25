variable "api_name" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "jwt_issuer" {
  type        = string
  description = "Cognito issuer URL (cognito 모듈의 issuer_url)"
}

variable "jwt_audience" {
  type        = list(string)
  description = "허용할 App Client ID 목록 (cognito 모듈의 client_id)"
}

variable "route_key" {
  type    = string
  default = "POST /access"
}

variable "cors_allow_origins" {
  type        = list(string)
  default     = ["*"]
  description = "브라우저에서 호출을 허용할 출처. 로그인 페이지 주소가 정해지면 좁힐 것"
}
