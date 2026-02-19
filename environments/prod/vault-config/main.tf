resource "vault_mount" "secret" {
  path    = "secret"
  type    = "kv"
  options = {
    version = "2"
  }
  description = "KV v2 secrets engine for application secrets"
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
}

# Policy: myapp read-only (pod-level access)
resource "vault_policy" "myapp_read" {
  name   = "myapp-read"
  policy = <<-EOT
    path "secret/data/myapp/*" {
      capabilities = ["read"]
    }
  EOT
}

# Policy: ESO read access (broader, for syncing secrets)
resource "vault_policy" "eso_read" {
  name   = "eso-read"
  policy = <<-EOT
    path "secret/data/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

# Role: myapp pod access
resource "vault_kubernetes_auth_backend_role" "myapp" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "myapp"
  bound_service_account_names      = ["myapp"]
  bound_service_account_namespaces = ["default"]
  token_policies                   = [vault_policy.myapp_read.name]
  token_ttl                        = 3600
}

# Role: ESO access
resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "external-secrets"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.eso_read.name]
  token_ttl                        = 3600
}
