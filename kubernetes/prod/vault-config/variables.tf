variable "vault_token" {
  description = "Vault root token (set via TF_VAR_vault_token)"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}
