output "repository_arn" {
  value = aws_ecr_repository.repo.arn
}

output "repository_url" {
  value = aws_ecr_repository.repo.repository_url
}
