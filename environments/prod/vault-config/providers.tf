terraform {
  required_version = ">= 1.14.0"

  backend "s3" {
    bucket = "terraform-state"
    key    = "prod/vault-config/terraform.tfstate"

    endpoints = {
      s3 = "http://192.168.1.178:9000"
    }

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true

    # Credentials via environment variables:
    # export AWS_ACCESS_KEY_ID="terraform-admin"
    # export AWS_SECRET_ACCESS_KEY="<from secure storage>"
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
