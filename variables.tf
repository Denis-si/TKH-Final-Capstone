variable "aws_region" {
  description = "Target AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Base VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "my_home_ip" {
  description = "Home IP address for restricted SSH ingress (format: x.x.x.x/32)"
  type        = string
  default     = "203.0.113.25/32" 
}