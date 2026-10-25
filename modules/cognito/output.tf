output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.user_pool.arn
}

output "client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "client_secret" {
  description = "generate_secret = true 일 때만 값이 있음"
  value       = aws_cognito_user_pool_client.client.client_secret
  sensitive   = true
}

# Spring Security (oauth2 resource server) 의 issuer-uri 에 사용
output "issuer_url" {
  value = "https://${aws_cognito_user_pool.user_pool.endpoint}"
}

output "hosted_ui_domain" {
  description = "domain_prefix 를 넣었을 때만 값이 있음"
  value       = try(aws_cognito_user_pool_domain.domain[0].domain, null)
}
