# these outputs tell you exactly what to put in the backend
# configuration of your other Terraform projects

output "state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.tflock.name
}

output "backend_config" {
  description = "Copy this into your Terraform backend block"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tfstate.bucket}"
      key            = "lab/terraform.tfstate"
      region         = "eu-north-1"
      dynamodb_table = "${aws_dynamodb_table.tflock.name}"
      encrypt        = true
    }
  EOT
}
