# data sources read existing information from AWS without creating anything
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "lab" {
  # account_id suffix ensures globally unique bucket name across all AWS accounts
  bucket = "terraform-lab-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# versioning is a separate resource — keeps every version of every object in the bucket
resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}
