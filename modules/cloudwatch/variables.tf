variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

variable "db_instance_id" {
  description = "RDS DB instance identifier"
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive SNS alarm notifications"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch Log Groups in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
