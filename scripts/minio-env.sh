#!/usr/bin/env bash
# Exporterar MinIO-credentials för Terraform mot Kubernetes/Vault.
#
# Användning (source, inte kör direkt):
#   source scripts/minio-env.sh
#
# Avaktivera:
#   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

export AWS_ACCESS_KEY_ID="terraform-admin"
# AWS_SECRET_ACCESS_KEY sätts inte här — hämta från din lösenordshanterare:
#   export AWS_SECRET_ACCESS_KEY="ditt-minio-lösenord"

echo "MinIO: AWS_ACCESS_KEY_ID=terraform-admin"
echo "Kom ihåg: export AWS_SECRET_ACCESS_KEY=\"...\""
