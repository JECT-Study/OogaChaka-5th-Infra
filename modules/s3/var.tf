variable "bucket_name" {
  type        = string
  description = "전 세계에서 유일해야 하는 버킷 이름"
}

variable "force_destroy" {
  type    = bool
  default = true
}

variable "objects" {
  type = map(object({
    content      = string
    content_type = string
  }))
  default     = {}
  description = "업로드할 파일 (key = 파일 경로, 예: index.html)"
}
