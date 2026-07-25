aws_region                = "us-east-1"
environment               = "prod"
vpc_cidr                  = "10.2.0.0/16"
availability_zones        = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs       = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_app_subnet_cidrs  = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
private_data_subnet_cidrs = ["10.2.100.0/24", "10.2.200.0/24", "10.2.300.0/24"]

single_nat_gateway   = false
instance_type        = "c6i.large"
asg_min_size         = 3
asg_max_size         = 12
asg_desired_capacity = 3

db_instance_class = "db.r6g.xlarge"
db_multi_az       = true

domain_name    = "app.enterprise.com"
hosted_zone_id = "Z1234567890ABC"
alarm_email    = "ops-alerts@enterprise.com"
