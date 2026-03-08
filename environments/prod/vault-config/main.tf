module "vault_config" {
  source = "../../../modules/vault-config"

  kubernetes_host = "https://kubernetes.default.svc"
  kv_path         = "secret"

  policies = {
    "eso-read" = {
      paths = {
        "secret/data/*"     = ["read"]
        "secret/metadata/*" = ["read", "list"]
      }
    }
  }

  kubernetes_roles = {
    "external-secrets" = {
      service_account_names      = ["external-secrets"]
      service_account_namespaces = ["external-secrets"]
      policies                   = ["eso-read"]
    }
  }

  secret_paths = {
    "external-dns/cloudflare"            = ["cloudflare-api-token"]
    "kube-prometheus-stack/grafana-admin" = ["admin-user", "admin-password"]
  }
}
