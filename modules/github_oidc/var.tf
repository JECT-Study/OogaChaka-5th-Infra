variable "oidc_provider_arn" {
  type        = string
  description = "GitHub OIDC 공급자 ARN (github_oidc_provider 모듈 출력)"
}

variable "role_name" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "배포를 허용할 GitHub 저장소 (조직/저장소 형식)"
}

variable "github_owner_id" {
  type        = string
  default     = null
  description = "조직(소유자) 숫자 ID. 토큰의 sub 가 repo:조직@ID/저장소@ID 형식일 때 github_repo_id 와 함께 지정 (Actions 로그에서 sub 확인)"
}

variable "github_repo_id" {
  type        = string
  default     = null
  description = "저장소 숫자 ID. github_owner_id 와 함께 지정"
}

variable "branch" {
  type    = string
  default = "main"
}

variable "deploy_bucket_arn" {
  type        = string
  description = "배포 파일을 올릴 S3 버킷 ARN"
}

variable "target_name_tag" {
  type        = string
  description = "SSM 명령을 보낼 EC2 의 Name 태그 값"
}

variable "ecr_push_repository_arns" {
  type        = list(string)
  default     = []
  description = "이미지를 push 할 ECR 저장소 ARN 목록 (비어 있으면 ECR 권한 없음)"
}
