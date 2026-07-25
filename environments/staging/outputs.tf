output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Application Load Balancer Public DNS Name"
  value       = module.alb.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = module.cloudfront.distribution_domain_name
}

output "rds_endpoint" {
  description = "RDS Database Endpoint"
  value       = module.rds.db_endpoint
}

output "s3_static_bucket" {
  description = "S3 Static Assets Bucket Name"
  value       = module.s3.static_bucket_id
}

output "cloudwatch_dashboard" {
  description = "CloudWatch Dashboard Name"
  value       = module.cloudwatch.dashboard_name
}
