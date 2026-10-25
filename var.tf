variable "key_name" {
    type = string
    default = "oogachaka_web"
    description = "콘솔에서 미리 생성한 기존 Key Pair 이름"
}

variable "cognito_domain_prefix" {
    type = string
    default = "ooga-chaka-5th"
    description = "Cognito Hosted UI 도메인 접두사 (같은 리전 안에서 유일해야 함)"
}

variable "admin_cidr" {
    type = string
    description = "SSH 접근을 허용할 관리자 IP (예: 1.2.3.4/32)"
}

variable "db_name" {
    type = string
    default = "oogachaka"
}

variable "db_username" {
    type = string
    default = "admin"
}

variable "db_password" {
    type = string
    sensitive = true
}
