output "log_group_name" {
  description = "Name of the EC2 CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "ARN of the EC2 CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS alarms topic"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch operations dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
