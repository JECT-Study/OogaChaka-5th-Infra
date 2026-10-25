output "db_endpoint" {
  value = aws_db_instance.rds.endpoint
}

output "db_port" {
  value = aws_db_instance.rds.port
}

output "db_address" {
  value = aws_db_instance.rds.address
}