output "api_endpoint" {
  description = "호출 주소 (예: POST <api_endpoint>/access)"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.api.id
}
