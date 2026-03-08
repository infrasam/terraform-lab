output "auth_backend_path" {
  value = module.vault_config.auth_backend_path
}

output "policy_names" {
  value = module.vault_config.policy_names
}

output "role_names" {
  value = module.vault_config.role_names
}
