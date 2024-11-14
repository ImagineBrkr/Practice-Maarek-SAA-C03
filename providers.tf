terraform {
  required_version = ">= 1.9.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.7.1"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = {
      Environment = "test"
      Course      = "Udemy-Maarek-SAA-C03"
    }
  }
}
