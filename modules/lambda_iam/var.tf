variable "role_name" {
  type = string
}

variable "statements" {
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
  default     = []
  description = "Lambda 에 부여할 추가 권한 (최소 권한 원칙으로 resources 를 좁혀서 전달)"
}
