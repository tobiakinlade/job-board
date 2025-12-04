# backend.tf
terraform {
  backend "s3" {
    bucket         = "job-board-terraform-state-180048382895"  # Create this bucket first
    key            = "eks/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "job-board-terraform-state-lock"       # Create this table first
  }
}
