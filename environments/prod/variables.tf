variable "aws_region" {
  description = "AWS Primary deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones list (3 AZs for Enterprise HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private app subnet CIDRs"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "Private data subnet CIDRs"
  type        = list(string)
  default     = ["10.2.100.0/24", "10.2.200.0/24", "10.2.300.0/24"]
}

variable "single_nat_gateway" {
  description = "Single NAT gateway option (false for HA in production)"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "c6i.large"
}

variable "asg_min_size" {
  description = "ASG minimum capacity"
  type        = number
  default     = 3
}

variable "asg_max_size" {
  description = "ASG maximum capacity"
  type        = number
  default     = 12
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 3
}

variable "db_instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "db_multi_az" {
  description = "RDS Multi-AZ enabled"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for Route53 and ACM"
  type        = string
  default     = "app.enterprise.com"
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = "Z1234567890ABC"
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = "ops-alerts@enterprise.com"
}
