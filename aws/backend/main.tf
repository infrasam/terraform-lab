# this configuration creates the resources needed to store
# Terraform state remotely. it is intentionally simple and
# rarely changes after initial creation.

data "aws_caller_identity" "current" {}

# --- S3 bucket for state storage ---
resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-${data.aws_caller_identity.current.account_id}"

  # prevent_destroy makes Terraform refuse to delete this bucket.
  # losing your state bucket = losing track of ALL your infrastructure.
  # you would have to manually import every resource back into state.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "terraform-state"
    ManagedBy = "terraform"
  }
}

# versioning — every state update creates a new version in S3.
# if a bad terraform apply corrupts state, you can go to the S3
# console, find the previous version, and restore it.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# server-side encryption — state is encrypted at rest in S3.
# AES256 is free and managed entirely by AWS (no key management needed).
# this protects the sensitive data in state (SSH keys, ARNs, etc.)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# block ALL public access — state must never be publicly readable.
# these four settings cover every possible way S3 can be made public:
#   - ACLs (legacy permission system)
#   - bucket policies
# belt and suspenders — even if someone adds a bad policy, this blocks it.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table for state locking ---
# when someone runs terraform apply, Terraform writes a lock entry here.
# if a second person tries to apply at the same time, Terraform sees the
# lock and refuses with an error instead of corrupting state.
#
# the table only needs one attribute: LockID (required by Terraform).
# PAY_PER_REQUEST means you pay per read/write — for state locking
# that is essentially zero cost.
resource "aws_dynamodb_table" "tflock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"   # S = string type
  }

  tags = {
    Name      = "terraform-lock"
    ManagedBy = "terraform"
  }
}
