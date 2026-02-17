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

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.29.1"
  namespace  = kubernetes_namespace.this["vault"].metadata[0].name

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "server.dev.devRootToken"
    value = "root"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }
}
