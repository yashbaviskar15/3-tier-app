aws_region                = "us-east-1"
environment               = "staging"
vpc_cidr                  = "10.1.0.0/16"
availability_zones        = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs       = ["10.1.1.0/24", "10.1.2.0/24"]
private_app_subnet_cidrs  = ["10.1.10.0/24", "10.1.20.0/24"]
private_data_subnet_cidrs = ["10.1.100.0/24", "10.1.200.0/24"]

single_nat_gateway   = false
instance_type        = "t3.small"
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2

db_instance_class = "db.t4g.small"
db_multi_az       = true

domain_name    = ""
hosted_zone_id = ""
alarm_email    = "devops-alerts-staging@example.com"
