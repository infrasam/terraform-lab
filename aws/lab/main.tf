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

# explicit route table for private subnets — no default route out
# without this, private subnets fall back to the VPC main route table
# which is implicit and dangerous: anyone adding a route there affects
# all unassociated subnets silently
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # no route block — only the automatic local route (10.0.0.0/16) exists
  # this means private subnets can talk within the VPC but NOT to the internet

  tags = {
    Name        = "lab-private-rt"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#AWS security group
resource "aws_security_group" "ssh" {
  name        = "lab-ssh"
  description = "Allow SSH inbound from trusted IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "lab-ssh-sg"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# COMPUTE
# ============================================================

# data source — asks AWS "what is the latest Amazon Linux 2023 AMI?"
# this runs at plan time, not apply time, so you always see which
# AMI will be used before you commit to anything.
#
# why not hardcode? AMI IDs are:
#   - different in every region (eu-north-1 vs us-east-1)
#   - replaced when Amazon publishes security patches
# a data source solves both problems automatically.
data "aws_ami" "amazon_linux" {
  most_recent = true       # if multiple match, pick the newest
  owners      = ["amazon"] # only official Amazon AMIs, not community uploads

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"] # Amazon Linux 2023, 64-bit
  }

  filter {
    name   = "state"
    values = ["available"] # skip AMIs that are still being created
  }
}

# generates an SSH key pair entirely within Terraform
# the private key will exist in terraform.tfstate — this is a security
# concern we address in Modul 4 (remote state with encryption).
# in production you would create keys outside Terraform and only
# import the public key here.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
  # ED25519 is a modern algorithm — shorter keys, faster operations,
  # and considered more secure than RSA. Most SSH clients support it.
  # if you run into compatibility issues, switch to RSA with 4096 bits.
}

# takes the public half of the key above and registers it in AWS
# so that EC2 instances can be launched with it.
# this does NOT put the private key in AWS — only the public key.
resource "aws_key_pair" "lab" {
  key_name   = "lab-key"
  public_key = tls_private_key.ssh.public_key_openssh
  # public_key_openssh is an attribute exported by tls_private_key
  # Terraform knows aws_key_pair depends on tls_private_key because
  # of this reference — that is the dependency graph in action.
}

# the actual virtual machine
resource "aws_instance" "lab" {
  ami                    = data.aws_ami.amazon_linux.id # from our data source
  instance_type          = var.instance_type            # t3.micro (Free Tier)
  subnet_id              = aws_subnet.public[0].id      # first public subnet
  vpc_security_group_ids = [aws_security_group.ssh.id]  # attach our firewall
  key_name               = aws_key_pair.lab.key_name    # SSH key for login

  # user_data is a script that runs ONCE at first boot via cloud-init.
  # it is the standard way to bootstrap an instance — install packages,
  # configure services, set hostname, etc.
  # the script runs as root. if it fails, the instance still starts
  # but your setup will be incomplete. check /var/log/cloud-init-output.log
  # on the instance to debug.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    hostnamectl set-hostname lab-instance
    dnf update -y
  EOF
  )

  # IMDS (Instance Metadata Service) is an HTTP endpoint at 169.254.169.254
  # that EC2 instances can query to learn about themselves (IP, role, etc.)
  # IMDSv1 has no authentication — any process on the instance can call it.
  # This is a known attack vector: if your app has an SSRF vulnerability,
  # an attacker can steal IAM credentials from IMDS.
  # IMDSv2 requires a session token, blocking that attack.
  metadata_options {
    http_endpoint = "enabled"  # IMDS is on
    http_tokens   = "required" # enforce v2 (token required)
  }

  # the root disk — where the OS lives
  root_block_device {
    volume_size = 8     # GB — Free Tier gives you 30 GB total across all instances
    volume_type = "gp3" # general purpose SSD, newest generation
    encrypted   = true  # encrypt data at rest — zero extra cost, always do this
  }

  tags = {
    Name        = "lab-instance"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# OUTPUTS
# ============================================================
# outputs print values after apply and make them available to
# other Terraform configurations (important when we get to modules).

output "instance_public_ip" {
  description = "Public IP of the lab instance"
  value       = aws_instance.lab.public_ip
}

output "ssh_private_key" {
  description = "Private SSH key — save to a file to connect"
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true # hides value in plan/apply terminal output
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i lab-key.pem ec2-user@${aws_instance.lab.public_ip}"
}
