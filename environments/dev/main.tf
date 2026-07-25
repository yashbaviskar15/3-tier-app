locals {
  name_prefix = "three-tier-${var.environment}"
  common_tags = {
    Project     = "Three-Tier-App"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 1. VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name_prefix               = local.name_prefix
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  single_nat_gateway        = var.single_nat_gateway
  tags                      = local.common_tags
}

# 2. Security Groups Module
module "security_groups" {
  source = "../../modules/security_groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  app_port    = 8080
  db_port     = 3306
  tags        = local.common_tags
}

# 3. S3 Module
module "s3" {
  source = "../../modules/s3"

  name_prefix    = local.name_prefix
  cloudfront_arn = module.cloudfront.distribution_arn
  force_destroy  = true
  tags           = local.common_tags
}

# 4. IAM Module
module "iam" {
  source = "../../modules/iam"

  name_prefix    = local.name_prefix
  s3_bucket_arns = [module.s3.static_bucket_arn, module.s3.logs_bucket_arn]
  tags           = local.common_tags
}

# 5. ACM Module (Regional ALB cert & CloudFront cert if domain provided)
module "acm" {
  count  = var.domain_name != "" ? 1 : 0
  source = "../../modules/acm"

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  hosted_zone_id            = var.hosted_zone_id
  tags                      = local.common_tags
}

# 6. ALB Module
module "alb" {
  source = "../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
  target_port       = 8080
  health_check_path = "/api/health"
  certificate_arn   = var.domain_name != "" ? module.acm[0].arn : ""
  logs_bucket_id    = module.s3.logs_bucket_id
  tags              = local.common_tags
}

# User Data Template Rendering
data "template_file" "user_data" {
  template = file("${path.module}/../../src/scripts/user_data.sh.tpl")

  vars = {
    aws_region     = var.aws_region
    db_secret_arn  = module.rds.secret_arn
    db_host        = module.rds.db_address
    db_user        = "admin"
    db_password    = ""
    db_name        = module.rds.db_name
    db_port        = module.rds.db_port
    app_port       = 8080
    log_group_name = module.cloudwatch.log_group_name
    package_json   = file("${path.module}/../../src/app/package.json")
    app_index_js   = file("${path.module}/../../src/app/index.js")
    app_index_html = file("${path.module}/../../src/app/public/index.html")
  }
}

# 7. Auto Scaling Group Module
module "asg" {
  source = "../../modules/asg"

  name_prefix               = local.name_prefix
  instance_type             = var.instance_type
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  private_subnet_ids        = module.vpc.private_app_subnet_ids
  target_group_arn          = module.alb.target_group_arn
  alb_arn_suffix            = module.alb.alb_arn_suffix
  target_group_arn_suffix   = module.alb.target_group_arn_suffix
  security_group_id         = module.security_groups.app_security_group_id
  iam_instance_profile_name = module.iam.instance_profile_name
  user_data_base64          = base64encode(data.template_file.user_data.rendered)
  tags                      = local.common_tags
}

# 8. RDS MySQL Module
module "rds" {
  source = "../../modules/rds"

  name_prefix             = local.name_prefix
  private_data_subnet_ids = module.vpc.private_data_subnet_ids
  security_group_id       = module.security_groups.rds_security_group_id
  allocated_storage       = 20
  instance_class          = var.db_instance_class
  multi_az                = var.db_multi_az
  db_name                 = "appdevdb"
  username                = "admin"
  deletion_protection     = false
  tags                    = local.common_tags
}

# 9. CloudFront Module
module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix             = local.name_prefix
  s3_bucket_domain_name   = module.s3.static_bucket_domain_name
  s3_bucket_id            = module.s3.static_bucket_id
  alb_dns_name            = module.alb.alb_dns_name
  acm_certificate_arn     = var.domain_name != "" ? module.acm[0].arn : ""
  domain_names            = var.domain_name != "" ? [var.domain_name] : []
  logs_bucket_domain_name = module.s3.logs_bucket_domain_name
  tags                    = local.common_tags
}

# 10. Route 53 Module
module "route53" {
  count  = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0
  source = "../../modules/route53"

  domain_name        = var.domain_name
  hosted_zone_id     = var.hosted_zone_id
  target_domain_name = module.cloudfront.distribution_domain_name
  target_zone_id     = module.cloudfront.distribution_hosted_zone_id
}

# 11. CloudWatch Operations Module
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  name_prefix    = local.name_prefix
  asg_name       = module.asg.asg_name
  alb_arn_suffix = module.alb.alb_arn_suffix
  db_instance_id = module.rds.db_instance_id
  alarm_email    = var.alarm_email
  tags           = local.common_tags
}
