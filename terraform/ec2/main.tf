#############################
# VARIABLES
#############################

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "pipeline_ip" {
  description = "Pipeline IP address"
  type        = string
}

variable "my_ip" {
  description = "Your own IP address"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile (optional)"
  type        = string
  default     = "default"
}


#############################
# PROVIDER
#############################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}


#############################
# DATA SOURCES
#############################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


#############################
# NETWORKING
#############################

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "vpc_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "subnet-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "igw-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "rt-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.vpc_subnet.id
  route_table_id = aws_route_table.rt.id
}


#############################
# SECURITY GROUP
#############################

resource "aws_security_group" "app_sg" {
  name        = "app-${var.environment}"
  description = "App SG: allow SSH, 8000, 8080 from pipeline + your IP"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow SSH from pipeline and your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.pipeline_ip}/32", "${var.my_ip}/32"]
  }

  ingress {
    description = "Allow app ports 8000/8080"
    from_port   = 8000
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.pipeline_ip}/32", "${var.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sg-app-${var.environment}"
    Environment = var.environment
  }
}


#############################
# EC2 INSTANCE + DOCKER INSTALL
#############################

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.vpc_subnet.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  key_name                    = "ssh-aws-test"

  user_data = <<-EOF
              #!/bin/bash
              set -e

              echo ">>> Updating system packages"
              apt-get update -y
              apt-get upgrade -y

              echo ">>> Installing prerequisites"
              apt-get install -y ca-certificates curl gnupg lsb-release

              echo ">>> Adding Docker’s official GPG key"
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

              echo ">>> Setting up Docker repository"
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

              echo ">>> Installing Docker Engine and Compose"
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              echo ">>> Adding ubuntu user to docker group"
              usermod -aG docker ubuntu

              echo ">>> Installing Docker Compose v2 (symlink for backward compat)"
              ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true

              echo ">>> Enabling and starting Docker"
              systemctl enable docker
              systemctl start docker

              echo ">>> Docker & Compose installation completed"
              docker --version
              docker compose version
              EOF

  tags = {
    Name        = "app-${var.environment}"
    Environment = var.environment
  }
}


#############################
# OUTPUTS
#############################

output "app_public_ip" {
  description = "Public IP of the application instance"
  value       = aws_instance.app.public_ip
}

output "app_ssh" {
  description = "SSH command for Application stack"
  value       = "ssh -i ~/.ssh/ssh-aws-test.pem ubuntu@${aws_instance.app.public_ip}"
}
