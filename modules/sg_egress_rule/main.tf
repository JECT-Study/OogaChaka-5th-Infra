resource "aws_vpc_security_group_egress_rule" "sg_egress_rule" {
  security_group_id            = var.security_group_id
  description                  = var.description
  ip_protocol                  = var.ip_protocol
  from_port                    = var.from_port
  to_port                      = var.to_port
  cidr_ipv4                    = var.cidr_ipv4
  referenced_security_group_id = var.referenced_security_group_id

  tags = var.tags
}