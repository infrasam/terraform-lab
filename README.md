# terraform-lab

Infrastructure as Code — labbmiljö för att lära och presentera Terraform.

## Struktur

```
terraform-lab/
├── kubernetes/                        # Kubernetes-infrastruktur (Vault på K8s)
│   ├── prod/
│   │   └── vault-config/              # Root module — Vault i produktion
│   │       ├── providers.tf           # Vault provider + S3 backend (MinIO)
│   │       ├── variables.tf           # vault_token (sensitive), environment
│   │       ├── main.tf                # Modulanrop med miljöspecifika värden
│   │       └── outputs.tf             # Exponerar auth path, policy/role-namn
│   └── modules/
│       └── vault-config/              # Återanvändbar modul
│           ├── main.tf                # Alla Vault-resurser
│           ├── variables.tf           # Input-variabler med typer
│           └── outputs.tf             # Modul-outputs
└── aws/                               # AWS-infrastruktur (under uppbyggnad)
    ├── lab/                           # Root module — AWS sandlåda
    └── modules/                       # Återanvändbara AWS-moduler
```

**Varför denna struktur?**

Top-level split per plattform (`kubernetes/`, `aws/`) gör det tydligt vad som
hör till vad. Inom varje plattform är varje katalog under `<plattform>/<miljö>/`
ett självständigt Terraform root module med eget state — ingen delad state
mellan plattformar eller miljöer.

- **Blast radius isolation** — en trasig ändring i AWS påverkar inte Kubernetes
- **DRY** — moduler skrivs en gång, parametriseras per miljö
- **Separat state** — varje root module har en egen state-fil

## Plattformar

### Kubernetes — Vault-konfiguration

Hanterar HashiCorp Vault på Kubernetes: KV secrets engine, Kubernetes auth
backend, policies och roller.

State lagras i MinIO (S3-kompatibel)
`terraform-state`, nyckel `prod/vault-config/terraform.tfstate`.

**Komma igång:**

```bash
cd kubernetes/prod/vault-config
export TF_VAR_vault_token="hvs.din-token"
export AWS_ACCESS_KEY_ID="terraform-admin"
export AWS_SECRET_ACCESS_KEY="ditt-minio-lösenord"
terraform init
terraform plan
```

### AWS — Lab (under uppbyggnad)

Kommer att innehålla: VPC, subnets, security groups, EC2, IAM — allt inom
AWS Free Tier.

## Relaterade repon

| Repo | Syfte |
|------|-------|
| [kubernetes-argocd-helm-helmfile-lab](https://github.com/infrasam/kubernetes-argocd-helm-helmfile-lab) | Vault Helm-deployment, ArgoCD, Helmfile |
