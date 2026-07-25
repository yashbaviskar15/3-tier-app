
# Temporary local backend for testing
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
