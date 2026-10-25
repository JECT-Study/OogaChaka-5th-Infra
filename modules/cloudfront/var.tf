variable "name" {
  type = string
}

variable "bucket_id" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "bucket_regional_domain_name" {
  type = string
}

variable "default_root_object" {
  type    = string
  default = "index.html"
}

# AWS 관리형 정책의 고정 ID (이름 조회에 필요한 List 권한을 피하려고 ID 를 직접 사용)
variable "cache_policy_id" {
  type        = string
  default     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  description = "Managed-CachingDisabled"
}

variable "response_headers_policy_id" {
  type        = string
  default     = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  description = "Managed-SecurityHeadersPolicy"
}

variable "price_class" {
  type        = string
  default     = "PriceClass_200"
  description = "PriceClass_200 에 아시아(한국) 엣지 포함"
}
