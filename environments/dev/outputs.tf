output "vault_namespace" {
  description = "Name of the vault namespace"
  value       = kubernetes_namespace.vault.metadata[0].name
}
