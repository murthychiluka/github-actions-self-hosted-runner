data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ============================================================
# SECURITY GROUPS
# ============================================================

resource "aws_security_group" "runner_sg" {
  name   = "runner-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # tighten to your IP later
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "runner-sg" }
}

resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description     = "SSH from runner only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.runner_sg.id]
  }
  ingress {
    description = "App port for testing"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app-sg" }
}

# ============================================================
# INSTANCES
# ============================================================

resource "aws_instance" "runner" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.runner_sg.id]
  key_name                    = "india-key.pem"
  associate_public_ip_address = true
  tags = { Name = "github-runner" }
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.public.ids[0]   # same subnet, no public IP = "private"
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = "india-key.pem"
  associate_public_ip_address = false
  tags = { Name = "app-server" }
}

output "runner_public_ip" {
  value = aws_instance.runner.public_ip
}

output "app_private_ip" {
  value = aws_instance.app_server.private_ip
}