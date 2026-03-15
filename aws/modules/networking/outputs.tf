# outputs are how the module passes information back to the caller.
# without these, the caller cannot reference the VPC or subnets
# that the module created — they are "inside" the module's scope.

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
  # the [*] syntax is called a "splat expression"
  # aws_subnet.public is a list (because of count), and [*].id
  # extracts the id attribute from each element.
  # result: ["subnet-abc123", "subnet-def456"]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
