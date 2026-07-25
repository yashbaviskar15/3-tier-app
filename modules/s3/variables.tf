variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "cloudfront_arn" {
  description = "ARN of the CloudFront distribution allowed to access static assets via OAC"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
