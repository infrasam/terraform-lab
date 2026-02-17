variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "namespaces" {
  description = "List of namespaces to create"
  type        = list(string)
  default     = ["vault", "monitoring", "ci"]
}
