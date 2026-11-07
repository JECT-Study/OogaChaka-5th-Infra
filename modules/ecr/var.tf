variable "name" {
  type        = string
  description = "ECR 저장소 이름"
}

variable "max_image_count" {
  type        = number
  default     = 2
  description = "저장소에 보관할 최대 이미지 수 (초과분은 오래된 순으로 자동 삭제)"
}

variable "force_delete" {
  type        = bool
  default     = false
  description = "true 면 이미지가 남아 있어도 terraform destroy 로 저장소를 삭제"
}
