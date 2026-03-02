terraform {
  required_version = ">= 1.14.0"

  # Backend block tells Terraform WHERE to store state
  # This is the first thing Terraform reads - before any other configuration
  # Once configured, all state operations go through this backend
  backend "s3" {
    bucket = "terraform-state"
    key    = "prod/vault-config/terraform.tfstate"

    # MinIO endpoint instead of AWS
    endpoints = {
      s3 = "http://192.168.1.178:9000"
    }

    # These disable AWS-specific features that MinIO doesn't support
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true

    # MinIO credentials
    access_key = "minioadmin"
    secret_key = "minioadmin123"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.6"
    }
  }
}

provider "vault" {
  address = "https://vault.k8slabs.se"
  token   = var.vault_token
}
