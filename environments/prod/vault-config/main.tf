# Call the vault-config module with prod-specific values
# The module contains the logic, this file contains only configuration
module "vault_config" {
  source = "../../../modules/vault-config"

  kubernetes_host = "https://kubernetes.default.svc"
  kv_path         = "secret"

  policies = {
    "myapp-read" = {
      paths = {
        "secret/data/myapp/*" = ["read"]
      }
    }
    "eso-read" = {
      paths = {
        "secret/data/*"     = ["read"]
        "secret/metadata/*" = ["read", "list"]
      }
    }
  }

  kubernetes_roles = {
    "myapp" = {
      service_account_names      = ["myapp"]
      service_account_namespaces = ["default"]
      policies                   = ["myapp-read"]
    }
    "external-secrets" = {
      service_account_names      = ["external-secrets"]
      service_account_namespaces = ["external-secrets"]
      policies                   = ["eso-read"]
    }
  }
}
