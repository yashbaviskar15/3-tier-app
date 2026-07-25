aws_region                = "us-east-1"
environment               = "dev"
vpc_cidr                  = "10.0.0.0/16"
availability_zones        = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs  = ["10.0.10.0/24", "10.0.20.0/24"]
private_data_subnet_cidrs = ["10.0.100.0/24", "10.0.200.0/24"]

single_nat_gateway   = true
instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 1

db_instance_class = "db.t4g.micro"
db_multi_az       = false

domain_name    = ""
hosted_zone_id = ""
alarm_email    = "devops-alerts-dev@example.com"
