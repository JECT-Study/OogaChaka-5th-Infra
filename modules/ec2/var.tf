variable "ami_id" {
  type        = string
}

variable "instance_type" {
  type        = string
}

variable "subnet_id" {
  type        = string
}

variable "security_group_ids" {
  type        = list(string)
}

variable "key_name" {
  type        = string
}

variable "associate_public_ip" {
  type        = bool
  default     = false
}

variable "volume_size" {
  type        = number
  default     = 20
}

variable "instance_name" {
  type        = string
}

variable "iam_instance_profile" {
  type        = string
  default     = null
  description = "EC2 에 붙일 인스턴스 프로파일 이름"
}
