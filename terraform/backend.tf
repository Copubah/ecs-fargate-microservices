terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket" # Change this
    key            = "ecs-microservices/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    # Enable versioning on the S3 bucket for state history
  }
}
