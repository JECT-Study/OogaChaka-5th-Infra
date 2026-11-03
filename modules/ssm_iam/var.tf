variable "name" {
  type        = string
  description = "역할 / 인스턴스 프로파일 이름"
}

variable "deploy_bucket_arn" {
  type        = string
  description = "EC2 가 배포 파일을 읽을 S3 버킷 ARN"
}
