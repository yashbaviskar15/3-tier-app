output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "The ID of the EC2 app instances security group"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "The ID of the RDS database security group"
  value       = aws_security_group.rds.id
}
