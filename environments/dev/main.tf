resource "kubernetes_namespace" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.key

    labels = {
      managed_by  = "terraform"
      environment = var.environment
    }
  }
}
