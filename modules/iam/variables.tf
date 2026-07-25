variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "s3_bucket_arns" {
  description = "ARNs of S3 buckets that EC2 instances need read access to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
