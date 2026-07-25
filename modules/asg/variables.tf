variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ASG placement"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of ALB Target Group to attach ASG instances"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of ALB for Request Count scaling policy"
  type        = string
  default     = ""
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of Target Group for Request Count scaling policy"
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "Security Group ID for EC2 instances"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

variable "user_data_base64" {
  description = "Base64 encoded user_data script for EC2 bootstrap"
  type        = string
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization percentage for ASG scaling"
  type        = number
  default     = 70.0
}

variable "target_requests_per_instance" {
  description = "Target ALB request count per instance for scaling"
  type        = number
  default     = 1000.0
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
