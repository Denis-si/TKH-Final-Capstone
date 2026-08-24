terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# DATA SOURCE: Amazon Linux 2023 AMI
# ------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# NETWORK ARCHITECTURE: VPC, Subnet, Internet Gateway, & Routing
# ------------------------------------------------------------------------------
resource "aws_vpc" "capstone_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "TKH-Capstone-VPC"
    Environment = "Production"
  }
}

resource "aws_internet_gateway" "capstone_igw" {
  vpc_id = aws_vpc.capstone_vpc.id

  tags = {
    Name = "TKH-Capstone-IGW"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.capstone_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "TKH-Capstone-Public-Subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.capstone_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.capstone_igw.id
  }

  tags = {
    Name = "TKH-Capstone-Public-RouteTable"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------------------------------
# FIREWALL / SECURITY GROUP: Ingress & Egress Rules
# ------------------------------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "tkh-capstone-web-sg"
  description = "Allow HTTP publicly and SSH restricted to admin IP"
  vpc_id      = aws_vpc.capstone_vpc.id

  # Public HTTP Ingress
  ingress {
    description      = "Allow public HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Restricted SSH Ingress
  ingress {
    description = "Allow SSH from restricted admin home IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_home_ip]
  }

  # Full Egress
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "TKH-Capstone-Web-SG"
  }
}

# ------------------------------------------------------------------------------
# COMPUTE: Amazon Linux 2023 EC2 Web Server
# ------------------------------------------------------------------------------
resource "aws_instance" "web_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>TKH Final Capstone - Automated Web Server</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name        = "TKH-Capstone-Web-Server"
    Environment = "Production"
  }
}