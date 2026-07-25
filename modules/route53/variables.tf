variable "domain_name" {
  description = "Primary domain name for Route53 record creation"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "target_domain_name" {
  description = "Target domain name for Alias (CloudFront or ALB DNS)"
  type        = string
}

variable "target_zone_id" {
  description = "Target hosted zone ID for Alias (CloudFront zone Z2FDTNDATAQYW2 or ALB zone ID)"
  type        = string
}

variable "record_name" {
  description = "Subdomain name for the record (e.g. www or app or empty for apex domain)"
  type        = string
  default     = ""
}
