variable "name" {
  type        = string
  description = "역할 / 인스턴스 프로파일 이름"
}

variable "deploy_bucket_arn" {
  type        = string
  description = "EC2 가 배포 파일을 읽을 S3 버킷 ARN"
}

variable "ecr_pull_repository_arns" {
  type        = list(string)
  default     = []
  description = "이미지를 pull 할 ECR 저장소 ARN 목록 (비어 있으면 ECR 권한 없음)"
}
