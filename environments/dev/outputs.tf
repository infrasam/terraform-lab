output "namespace_names" {
  description = "Names of created namespaces"
  value       = [for ns in kubernetes_namespace.this : ns.metadata[0].name]
}
