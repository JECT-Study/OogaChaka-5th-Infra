output "public_ip" {
  value = aws_eip.eip.public_ip
}

output "allocation_id" {
  value = aws_eip.eip.id
}