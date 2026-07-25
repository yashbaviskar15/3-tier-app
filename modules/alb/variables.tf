variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB and Target Group reside"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB placement"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID for the ALB"
  type        = string
}

variable "target_port" {
  description = "Port on which target app instances listen"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/api/health"
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener (optional)"
  type        = string
  default     = ""
}

variable "logs_bucket_id" {
  description = "ID of S3 bucket for ALB access logging (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
