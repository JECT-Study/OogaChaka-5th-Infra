variable "security_group_id" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "ip_protocol" {
  type    = string
  default = "-1"
}

variable "from_port" {
  type    = number
  default = null
}

variable "to_port" {
  type    = number
  default = null
}

variable "cidr_ipv4" {
  type    = string
  default = "0.0.0.0/0"
}

variable "referenced_security_group_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}