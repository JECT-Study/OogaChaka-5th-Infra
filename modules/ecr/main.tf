resource "aws_ecr_repository" "repo" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.name
  }
}

# 이미지는 최신 N개만 보관하고 나머지는 자동 삭제 (태그 유무와 관계없이 push 시각 기준)
resource "aws_ecr_lifecycle_policy" "keep_latest" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the latest ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
