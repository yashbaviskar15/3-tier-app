variable "domain_name" {
  description = "Primary domain name for the ACM SSL certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Set of domains that should be SANs in the issued certificate"
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for DNS validation"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
