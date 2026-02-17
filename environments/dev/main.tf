resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"

    labels = {
      managed_by  = "terraform"
      environment = "dev"
    }
  }
}
