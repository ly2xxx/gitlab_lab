terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Allows running terraform validate and terraform test without real credentials.
  # In a real deployment these should be removed.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "gitlab-lab-23"
    }
  }
}
