output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.clinic_host.id
}

output "instance_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.clinic_host.public_ip
}

output "ssh_command" {
  description = "Command for connecting to the EC2 instance"
  value       = "ssh -i labsuser.pem ubuntu@${aws_instance.clinic_host.public_ip}"
}

output "application_url" {
  description = "Application NodePort URL"
  value       = "http://${aws_instance.clinic_host.public_ip}:30080"
}