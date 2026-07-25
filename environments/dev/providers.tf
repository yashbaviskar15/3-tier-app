terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Three-Tier-App"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

# us-east-1 provider for CloudFront ACM Certificate
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "Three-Tier-App"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}
