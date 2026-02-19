terraform {
  required_version = ">= 1.14.0"

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
