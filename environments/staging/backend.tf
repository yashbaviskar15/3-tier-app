terraform {
  backend "s3" {
    bucket         = "three-tier-tf-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "three-tier-tf-locks-staging"
    encrypt        = true
  }
}
