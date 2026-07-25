# Configure Remote S3 Backend with DynamoDB State Locking
# Replace bucket and dynamodb_table values during backend initialization:
# terraform init -backend-config="bucket=my-tf-state-bucket" -backend-config="dynamodb_table=my-tf-locks"

terraform {
  backend "s3" {
    bucket         = "three-tier-tf-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "three-tier-tf-locks-dev"
    encrypt        = true
  }
}
