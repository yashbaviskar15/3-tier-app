variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "app_port" {
  description = "Port on which EC2 app instances listen"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port on which RDS database listens"
  type        = number
  default     = 3306
}

variable "tags" {
  description = "Map of tags to assign to security groups"
  type        = map(string)
  default     = {}
}
