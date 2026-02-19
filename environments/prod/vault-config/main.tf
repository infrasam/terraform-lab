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

resource "vault_policy" "myapp_read" {
  name   = "myapp-read"
  policy = <<-EOT
    path "secret/data/myapp/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "myapp" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "myapp"
  bound_service_account_names      = ["myapp"]
  bound_service_account_namespaces = ["default"]
  token_policies                   = [vault_policy.myapp_read.name]
  token_ttl                        = 3600
}
