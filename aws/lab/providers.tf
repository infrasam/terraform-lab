terraform {
  required_version = ">= 1.14.0" # fail early if someone runs an older Terraform

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # allow 5.x, never 6.x (major versions may have breaking changes)
    }
  }
}

provider "aws" {
  region = var.aws_region
}
