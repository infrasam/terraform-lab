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
# for_each loops over the policies map from variables
# If you pass 2 policies, Terraform creates 2 vault_policy resources
# If you pass 10, it creates 10 - without changing this code
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
# Same pattern - one role per entry in the kubernetes_roles map
# each.key = role name, each.value = role configuration
resource "vault_kubernetes_auth_backend_role" "this" {
  for_each                         = var.kubernetes_roles
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = each.value.service_account_names
  bound_service_account_namespaces = each.value.service_account_namespaces
  token_policies                   = each.value.policies
  token_ttl                        = each.value.token_ttl
}
