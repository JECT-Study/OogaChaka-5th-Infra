variable "rule_name" {
  type = string
}

variable "schedule_expression" {
  type    = string
  default = "rate(5 minutes)"
}

variable "lambda_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}
