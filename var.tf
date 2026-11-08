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

variable "discord_webhook_url" {
    type = string
    description = "RDS 시작/종료 알림을 보낼 Discord 웹훅 URL (terraform.tfvars 에 작성, 커밋 금지)"
}

variable "redis_password" {
    type = string
    sensitive = true
    description = "log EC2 의 Redis 비밀번호 (terraform.tfvars 에 작성, 커밋 금지). 12자 이상, 영문/숫자와 # _ - . @ + = : 만 사용. 예: openssl rand -hex 16"

    validation {
        # 셸/compose 에서 깨지는 문자($ " ' \ 공백 등)는 막고, # _ - . @ + = : 는 허용한다
        condition     = can(regex("^[A-Za-z0-9#_.@+=:-]{12,}$", var.redis_password))
        error_message = "redis_password 는 12자 이상, 영문/숫자와 # _ - . @ + = : 만 쓸 수 있습니다."
    }
}

variable "domain" {
    type = string
    description = "web 서버 도메인 (예: dev.example.com). 비우면 HTTPS 없이 80 포트만 사용. DNS A 레코드를 web EIP 로 연결해 둘 것"
}

variable "cert_email" {
    type = string
    description = "Let's Encrypt 인증서 발급/만료 알림 이메일. domain 과 함께 지정해야 HTTPS 가 켜진다"
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
