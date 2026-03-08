output "auth_backend_path" {
  description = "Path of the Kubernetes auth backend"
  value       = vault_auth_backend.kubernetes.path
}

output "policy_names" {
  description = "Names of created policies"
  value       = [for p in vault_policy.this : p.name]
}

output "role_names" {
  description = "Names of created roles"
  value       = [for r in vault_kubernetes_auth_backend_role.this : r.role_name]
}
