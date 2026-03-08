# KV v2 secrets engine
resource "vault_mount" "secret" {
  path        = var.kv_path
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 secrets engine for application secrets"
}

# Kubernetes auth backend
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = var.kubernetes_host
}

# Dynamic policies
resource "vault_policy" "this" {
  for_each = var.policies
  name     = each.key
  policy   = join("\n", [
    for path, capabilities in each.value.paths : <<-EOT
      path "${path}" {
        capabilities = ${jsonencode(capabilities)}
      }
    EOT
  ])
}

# Dynamic roles
resource "vault_kubernetes_auth_backend_role" "this" {
  for_each                         = var.kubernetes_roles
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = each.value.service_account_names
  bound_service_account_namespaces = each.value.service_account_namespaces
  token_policies                   = each.value.policies
  token_ttl                        = each.value.token_ttl
}

# Application secret namespaces
# Creates a top-level path per app with an .initialized marker
# All actual secrets under each path are managed in Vault UI
resource "vault_kv_secret_v2" "namespace" {
  for_each = toset(var.secret_namespaces)
  mount    = vault_mount.secret.path
  name     = "${each.value}/.initialized"

  data_json = jsonencode({
    managed_by = "terraform"
    purpose    = "Marker to ensure this secret namespace exists. Create secrets under this path in Vault UI."
  })

  lifecycle {
    ignore_changes = [data_json]
  }
}
