data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "lab" {
  bucket = "terraform-lab-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# NETWORKING — now provided by the reusable module
# ============================================================

# the module block replaces ~80 lines of networking code.
# source points to a local directory. it can also point to a git
# repo or the Terraform Registry — but local is fine for now.
#
# every variable in modules/networking/variables.tf that has no
# default MUST be passed here. if you forget one, Terraform will
# tell you at plan time.
module "networking" {
  source = "../modules/networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = "lab"
}

# ============================================================
# COMPUTE
# ============================================================

# note how references changed:
#   before: aws_vpc.main.id           → now: module.networking.vpc_id
#   before: aws_subnet.public[0].id   → now: module.networking.public_subnet_ids[0]
# the module encapsulates the resources — you can only access what
# the module explicitly exports via its outputs.tf.

resource "aws_security_group" "ssh" {
  name        = "lab-ssh"
  description = "Allow SSH inbound from trusted IP"
  vpc_id      = module.networking.vpc_id  # ← changed

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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "lab" {
  key_name   = "lab-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_instance" "lab" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = module.networking.public_subnet_ids[0]  # ← changed
  vpc_security_group_ids = [aws_security_group.ssh.id]
  key_name               = aws_key_pair.lab.key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    hostnamectl set-hostname lab-instance
    dnf update -y
  EOF
  )

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
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

output "instance_public_ip" {
  description = "Public IP of the lab instance"
  value       = aws_instance.lab.public_ip
}

output "ssh_private_key" {
  description = "Private SSH key — save to a file to connect"
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i lab-key.pem ec2-user@${aws_instance.lab.public_ip}"
}
