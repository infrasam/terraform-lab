output "auth_backend_path" {
  description = "Path of the Kubernetes auth backend"
  value       = vault_auth_backend.kubernetes.path
}

output "myapp_role" {
  description = "Name of the myapp Vault role"
  value       = vault_kubernetes_auth_backend_role.myapp.role_name
}
