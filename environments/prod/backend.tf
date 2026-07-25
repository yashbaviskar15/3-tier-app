terraform {
  backend "s3" {
    bucket         = "three-tier-tf-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "three-tier-tf-locks-prod"
    encrypt        = true
  }
}
