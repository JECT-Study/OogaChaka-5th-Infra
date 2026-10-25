output "domain_name" {
  description = "예: d1234abcd.cloudfront.net"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.cdn.arn
}
