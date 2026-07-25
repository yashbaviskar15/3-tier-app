variable "aws_region" {
  description = "AWS Primary deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones list"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private app subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "Private data subnet CIDRs"
  type        = list(string)
  default     = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "single_nat_gateway" {
  description = "Cost optimization: use single NAT gateway for dev"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 Instance type"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "ASG minimum capacity"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG maximum capacity"
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "RDS DB instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "RDS Multi-AZ enabled"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Route53 and ACM (Optional)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID (Optional)"
  type        = string
  default     = ""
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms (Optional)"
  type        = string
  default     = ""
}
