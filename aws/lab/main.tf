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

# ============================================================
# NETWORKING
# ============================================================

# data source — reads available AZs in the current region at plan time
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # required for DNS resolution inside the VPC
  enable_dns_hostnames = true # assigns DNS names to EC2 instances (needed later)

  tags = {
    Name        = "lab-vpc"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# count creates one resource per list item — index 0 → AZ a, index 1 → AZ b
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # instances launched here automatically get a public IP
  map_public_ip_on_launch = true

  tags = {
    Name        = "lab-public-${count.index + 1}"
    Environment = "lab"
    ManagedBy   = "terraform"
    Type        = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "lab-private-${count.index + 1}"
    Environment = "lab"
    ManagedBy   = "terraform"
    Type        = "private"
  }
}

# internet gateway — the door between the VPC and the public internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "lab-igw"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# route table for public subnets — sends all non-local traffic to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # default route — matches all traffic not in the VPC
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "lab-public-rt"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# associations link each public subnet to the route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
