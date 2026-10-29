variable "topic_name" {
  type = string
}

variable "db_identifier" {
  type = string
}

variable "event_categories" {
  type = list(string)
}

variable "lambda_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}
