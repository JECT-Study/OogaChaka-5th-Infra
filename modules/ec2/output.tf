output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.ec2.id
}

output "private_ip" {
  description = "EC2 private IP"
  value       = aws_instance.ec2.private_ip
}

output "public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.ec2.public_ip
}