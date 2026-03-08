# Terraform Homelab - Vault Configuration

Infrastructure as Code for HashiCorp Vault configuration on Kubernetes, managed via Terraform.

## Repository Structure

```
terraform-lab/
├── README.md
├── environments/
│   └── prod/
│       └── vault-config/          # Root module for production
│           ├── providers.tf       # Vault provider + S3 backend (MinIO)
│           ├── variables.tf       # vault_token (sensitive), environment
│           ├── main.tf            # Module invocation with environment-specific values
│           └── outputs.tf         # Exposes auth path, policy/role names
└── modules/
    └── vault-config/              # Reusable module
        ├── main.tf                # All Vault resources
        ├── variables.tf           # Input variables with types
        └── outputs.tf             # Module outputs
```

**Why this structure?**

Each directory under `environments/` is an independent Terraform root module with its own state. The `modules/` directory contains reusable logic. This gives us:

- **Blast radius isolation** — a bad change in prod doesn't affect other environments
- **DRY code** — the module is written once, parameterized per environment
- **Separate state** — each environment has its own state file in MinIO

## Prerequisites

- [tfenv](https://github.com/tfutils/tfenv) installed (`~/.tfenv/bin` in PATH)
- Terraform >= 1.14.0 (managed by tfenv)
- Access to Vault
- Vault root token (for initial setup) or admin token
- MinIO running for remote state

## Getting Started

### 1. Clone and initialize

```bash
git clone git@github.com:infrasam/terraform-homelab.git
cd terraform-homelab/environments/prod/vault-config

# Set Vault token (never hardcode this)
export TF_VAR_vault_token="hvs.your-token-here"

# Initialize Terraform (downloads providers, connects to MinIO backend)
terraform init
```

### 2. Review changes before applying

```bash
terraform plan
```

Always read the plan output carefully:

| Symbol | Meaning |
|--------|---------|
| `+` | Resource will be created |
| `~` | Resource will be updated in-place |
| `-/+` | Resource will be destroyed and recreated (**dangerous!**) |
| `-` | Resource will be destroyed |

**If you see `-/+` (destroy/recreate) on `vault_mount.secret`, STOP.** That would delete all secrets. Check if `type` is set to `kv` with `options = { version = "2" }` (not `kv-v2`).

### 3. Apply changes

```bash
terraform apply
```

Type `yes` to confirm. For CI/CD pipelines, use `terraform apply -auto-approve` only after a successful plan review.

## Common Tasks

### Add a new application to Vault

This creates a Vault policy, a Kubernetes auth role, and a secret namespace marker.

**Step 1:** Edit `environments/prod/vault-config/main.tf`:

```hcl
module "vault_config" {
  source = "../../../modules/vault-config"

  # ... existing config ...

  policies = {
    # Existing policies...
    "eso-read" = {
      paths = {
        "secret/data/*"     = ["read"]
        "secret/metadata/*" = ["read", "list"]
      }
    }

    # ADD: New application policy
    "myapp-read" = {
      paths = {
        "secret/data/myapp/*" = ["read"]
      }
    }
  }

  kubernetes_roles = {
    # Existing roles...
    "external-secrets" = {
      service_account_names      = ["external-secrets"]
      service_account_namespaces = ["external-secrets"]
      policies                   = ["eso-read"]
    }

    # ADD: New application role
    "myapp" = {
      service_account_names      = ["myapp"]
      service_account_namespaces = ["default"]
      policies                   = ["myapp-read"]
      token_ttl                  = 3600  # optional, defaults to 3600 (1h)
    }
  }

  secret_namespaces = [
    "external-dns",
    "kube-prometheus-stack",
    "myapp",               # ADD: Creates secret/myapp/.initialized in Vault
  ]
}
```

**Step 2:** Plan and apply:

```bash
terraform plan   # Verify: should show + create, no destroys
terraform apply
```

**Step 3:** Create the actual secret in Vault UI or CLI:

```bash
# Via kubectl exec
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault kv put secret/myapp/config key1=value1 key2=value2'

# Via Vault UI: https://vault.k8slabs.se → Secrets → secret/ → myapp/
```

### Add a new policy

Policies follow the format `path → capabilities`. Available capabilities:

| Capability | Description |
|-----------|-------------|
| `create` | Create new secrets |
| `read` | Read secret data |
| `update` | Modify existing secrets |
| `delete` | Delete secrets |
| `list` | List secrets at a path |

Example policies:

```hcl
policies = {
  # Read-only access to specific app
  "myapp-read" = {
    paths = {
      "secret/data/myapp/*" = ["read"]
    }
  }

  # Read + write for CI/CD
  "ci-write" = {
    paths = {
      "secret/data/ci/*"     = ["create", "read", "update"]
      "secret/metadata/ci/*" = ["read", "list"]
    }
  }

  # Broad read for ESO (syncs secrets to Kubernetes)
  "eso-read" = {
    paths = {
      "secret/data/*"     = ["read"]
      "secret/metadata/*" = ["read", "list"]
    }
  }
}
```

**Important:** KV v2 uses `secret/data/*` for secret values and `secret/metadata/*` for listing. If your app needs to list secrets, include both paths.

### Add a new Kubernetes auth role

Roles bind a Kubernetes ServiceAccount to one or more Vault policies:

```hcl
kubernetes_roles = {
  "my-role" = {
    service_account_names      = ["sa-name"]           # K8s ServiceAccount name
    service_account_namespaces = ["namespace"]          # K8s namespace
    policies                   = ["policy1", "policy2"] # Vault policies to attach
    token_ttl                  = 3600                   # Token lifetime in seconds (default: 1h)
  }
}
```

The role name becomes the `role` parameter when authenticating against Vault from a pod.

### Create secrets in Vault

Terraform manages the **structure** (policies, roles, namespace markers). Actual secret **values** are managed in Vault directly — never store secret values in Terraform code or state.

```bash
# Write a secret
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault kv put secret/<app>/config key=value'

# Read a secret
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault kv get secret/<app>/config'

# List secrets under a path
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault kv list secret/<app>'

# Delete a secret
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault kv delete secret/<app>/config'

# Via Vault UI: https://vault.k8slabs.se
```

## Terraform State Management

State is stored remotely in MinIO (S3-compatible) at `192.168.1.178:9000`, bucket `terraform-state`.

### Viewing state

```bash
# List all resources in state
terraform state list

# Show details of a specific resource
terraform state show 'module.vault_config.vault_policy.this["eso-read"]'
```

### Moving resources (refactoring)

When you rename a resource in code, Terraform sees it as "delete old + create new". Use `state mv` to tell Terraform it's the same resource:

```bash
# Example: renaming a policy
terraform state mv \
  'module.vault_config.vault_policy.this["old-name"]' \
  'module.vault_config.vault_policy.this["new-name"]'
```

**Always run `terraform plan` after `state mv`** to verify it shows no changes.

### Removing from state (without destroying)

If you want Terraform to stop managing a resource without deleting it from Vault:

```bash
terraform state rm 'module.vault_config.vault_kv_secret_v2.namespace["app-name"]'
```

The resource remains in Vault but Terraform no longer tracks it.

### Importing existing resources

If a resource was created manually and you want Terraform to manage it:

```bash
# Import a KV mount
terraform import 'module.vault_config.vault_mount.secret' secret

# Import a policy
terraform import 'module.vault_config.vault_policy.this["policy-name"]' policy-name

# Import a Kubernetes auth backend
terraform import 'module.vault_config.vault_auth_backend.kubernetes' kubernetes
```

**After import**, run `terraform plan` to check for drift between Terraform code and actual state.

## Vault Bootstrap (One-Time)

These steps are performed once when setting up a new Vault cluster. They cannot be automated via Terraform because Vault must be running and accessible first.

### Initialize Vault

```bash
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json
```

**Save the output securely.** It contains 5 unseal keys and a root token. In production, distribute each key to a separate person.

### Unseal Vault (required after every pod restart)

Each Vault pod must be unsealed individually with 3 of 5 keys:

```bash
# Unseal vault-0
kubectl exec -n vault vault-0 -- vault operator unseal <KEY1>
kubectl exec -n vault vault-0 -- vault operator unseal <KEY2>
kubectl exec -n vault vault-0 -- vault operator unseal <KEY3>

# Join and unseal vault-1
kubectl exec -n vault vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n vault vault-1 -- vault operator unseal <KEY1>
kubectl exec -n vault vault-1 -- vault operator unseal <KEY2>
kubectl exec -n vault vault-1 -- vault operator unseal <KEY3>

# Join and unseal vault-2
kubectl exec -n vault vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n vault vault-2 -- vault operator unseal <KEY1>
kubectl exec -n vault vault-2 -- vault operator unseal <KEY2>
kubectl exec -n vault vault-2 -- vault operator unseal <KEY3>
```

### Enable KV secrets engine

```bash
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<root-token> vault secrets enable -path=secret kv-v2'
```

After bootstrap, run `terraform import` to bring the KV mount into state, then `terraform apply` for the rest.

### Verify cluster health

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# Check Raft peers
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault operator raft list-peers'

# Expected: 3 nodes — 1 leader, 2 followers
```

## Troubleshooting

### "security barrier not initialized"

Vault is waiting for `vault operator init`. This is normal on a fresh deployment.

### PVCs stuck in Terminating

Scale down the StatefulSet first, then patch out finalizers:

```bash
kubectl scale statefulset vault -n vault --replicas=0
kubectl patch pvc data-vault-0 -n vault -p '{"metadata":{"finalizers":null}}'
kubectl patch pvc data-vault-1 -n vault -p '{"metadata":{"finalizers":null}}'
kubectl patch pvc data-vault-2 -n vault -p '{"metadata":{"finalizers":null}}'
```

### "permission denied" on raft list-peers

You need to pass a valid Vault token:

```bash
kubectl exec -n vault vault-0 -- sh -c \
  'VAULT_TOKEN=<token> vault operator raft list-peers'
```

### Terraform wants to destroy vault_mount.secret

Check that the mount uses `type = "kv"` with `options = { version = "2" }`, not `type = "kv-v2"`. Vault internally represents KV v2 as type `kv` with a version option.

### Vault pods not scheduling (anti-affinity)

On a single-node cluster, use soft anti-affinity in the Helm values. This is configured in the kubernetes-argocd-helm-helmfile-lab repo, not here.

## Git Workflow

```bash
# Create feature branch
git checkout -b feat/add-myapp-policy

# Make changes to environments/prod/vault-config/main.tf
# ...

# Plan and verify
export TF_VAR_vault_token="hvs.your-token"
cd environments/prod/vault-config
terraform plan

# Apply if plan looks good
terraform apply

# Commit with conventional commits
git add .
git commit -m "feat: add myapp policy and role

- Create myapp-read policy with read access to secret/data/myapp/*
- Create myapp Kubernetes auth role bound to myapp ServiceAccount
- Add myapp to secret namespaces"

git push -u origin feat/add-myapp-policy
# Create PR, review, merge
```

## Related Repositories

| Repository | Purpose |
|-----------|---------|
| [kubernetes-argocd-helm-helmfile-lab](https://github.com/infrasam/kubernetes-argocd-helm-helmfile-lab) | Vault Helm deployment, ArgoCD, Helmfile releases |
| [terraform-homelab](https://github.com/infrasam/terraform-homelab) | This repo — Vault configuration via Terraform |
