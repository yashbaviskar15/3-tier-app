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
      Environment = "staging"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "Three-Tier-App"
      Environment = "staging"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}
