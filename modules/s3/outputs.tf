output "static_bucket_id" {
  description = "The ID/Name of the static assets S3 bucket"
  value       = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  description = "The ARN of the static assets S3 bucket"
  value       = aws_s3_bucket.static.arn
}

output "static_bucket_domain_name" {
  description = "The bucket regional domain name of the static assets S3 bucket"
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}

output "logs_bucket_id" {
  description = "The ID/Name of the access logs S3 bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "The ARN of the access logs S3 bucket"
  value       = aws_s3_bucket.logs.arn
}

output "logs_bucket_domain_name" {
  description = "The bucket domain name of the access logs S3 bucket"
  value       = aws_s3_bucket.logs.bucket_domain_name
}
