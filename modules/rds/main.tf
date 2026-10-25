resource "aws_db_subnet_group" "rds" {
  name = var.db_subnet_group_name

  subnet_ids = var.private_subnet_ids

  tags = {
    Name = var.db_subnet_group_name
  }
}

resource "aws_db_instance" "rds" {
  identifier = var.db_identifier

  engine         = "mysql"
  instance_class = var.instance_class

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = var.security_group_ids

  publicly_accessible = false
  multi_az             = false

  skip_final_snapshot = true

  tags = {
    Name = var.db_identifier
  }
}