locals {
  # 부팅할 때마다 /etc/ooga/env 를 다시 쓴다 (cloud-init per-boot 스크립트)
  env_script = join("\n", concat(
    ["#!/bin/bash", "mkdir -p /etc/ooga", "cat > /etc/ooga/env <<'ENVEOF'"],
    [for k, v in var.env_vars : "${k}=${v}"],
    ["ENVEOF", "chmod 644 /etc/ooga/env"]
  ))

  user_data = length(var.env_vars) > 0 ? join("\n", [
    "Content-Type: multipart/mixed; boundary=\"==OOGA_BOUNDARY==\"",
    "MIME-Version: 1.0",
    "",
    "--==OOGA_BOUNDARY==",
    "Content-Type: text/x-shellscript-per-boot; charset=\"us-ascii\"",
    "",
    local.env_script,
    "--==OOGA_BOUNDARY==--",
    ""
  ]) : null
}

resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile
  user_data              = local.user_data

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = var.instance_name
  }
}