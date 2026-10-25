variable "db_subnet_group_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_identifier" {
  type = string
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "security_group_ids" {
  type = list(string)
}