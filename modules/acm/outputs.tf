output "arn" {
  description = "The ARN of the ACM Certificate"
  value       = aws_acm_certificate.cert.arn
}

output "domain_validation_options" {
  description = "Set of domain validation objects which can be used to complete certificate validation"
  value       = aws_acm_certificate.cert.domain_validation_options
}
