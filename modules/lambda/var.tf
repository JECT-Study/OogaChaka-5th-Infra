variable "function_name" {
  type = string
}

variable "source_dir" {
  type        = string
  description = "handler 코드가 들어 있는 폴더 (zip 으로 묶어서 배포)"
}

variable "role_arn" {
  type = string
}

variable "handler" {
  type    = string
  default = "handler.lambda_handler"
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "architecture" {
  type    = string
  default = "arm64"
}

variable "timeout" {
  type    = number
  default = 30
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 14
}
