variable "kubernetes_host" {
  description = "Kubernetes API server URL"
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "kv_path" {
  description = "Path for the KV v2 secrets engine"
  type        = string
  default     = "secret"
}

variable "policies" {
  description = "Map of Vault policies to create"
  type = map(object({
    paths = map(list(string))
  }))
}

variable "kubernetes_roles" {
  description = "Map of Kubernetes auth roles to create"
  type = map(object({
    service_account_names      = list(string)
    service_account_namespaces = list(string)
    policies                   = list(string)
    token_ttl                  = optional(number, 3600)
  }))
}

variable "secret_paths" {
  description = "Map of secret paths to create with initial placeholder keys"
  type = map(list(string))
}
