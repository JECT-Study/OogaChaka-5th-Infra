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
