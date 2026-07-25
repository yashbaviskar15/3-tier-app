variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "S3 bucket regional domain name for static origin"
  type        = string
}

variable "s3_bucket_id" {
  description = "S3 bucket ID"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for dynamic API origin"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN in us-east-1 for CloudFront custom domain"
  type        = string
  default     = ""
}

variable "domain_names" {
  description = "List of custom domain names / CNAMEs"
  type        = list(string)
  default     = []
}

variable "logs_bucket_domain_name" {
  description = "Domain name of S3 logging bucket"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
