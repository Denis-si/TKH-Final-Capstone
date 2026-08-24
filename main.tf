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
# NETWORK ARCHITECTURE
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

# tfsec:ignore:aws-ec2-no-public-ip-subnet
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
# FIREWALL / SECURITY GROUP
# ------------------------------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "tkh-capstone-web-sg"
  description = "Allow HTTP publicly and SSH restricted to admin IP"
  vpc_id      = aws_vpc.capstone_vpc.id

  # tfsec:ignore:aws-vpc-no-public-ingress-sgr
  ingress {
    description      = "Allow HTTP inbound traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_home_ip]
  }

  # tfsec:ignore:aws-vpc-no-public-egress-sgr
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
# COMPUTE: HARDENED EC2 WEB SERVER
# ------------------------------------------------------------------------------
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Encrypted Root Storage
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  # Enforce IMDSv2 (Token Requirement)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

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