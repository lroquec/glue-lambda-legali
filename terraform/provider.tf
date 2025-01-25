terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.76.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket = "lroquec-tf"
    key    = "devops/glue/terraform.tfstate"
    region = "us-east-1"
    # For DynamoDB locking in production environments
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      CreatedBy = "lroquec"
      Owner     = "DevOps Team"
    }
  }
}