variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "private_data_subnet_ids" {
  description = "List of isolated private data subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage size in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit to which autoscaling can extend storage in GB"
  type        = number
  default     = 100
}

variable "engine_version" {
  description = "MySQL database engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "multi_az" {
  description = "Specifies if the RDS instance is Multi-AZ"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "username" {
  description = "Master username for database"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "Master password for database (Optional: if blank, random password will be generated and stored in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "If true, database cannot be destroyed without explicit override"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
