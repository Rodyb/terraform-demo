#############################
# PROVIDER
#############################

provider "aws" {
  region = "eu-central-1"
}

#############################
# AMI
#############################

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

#############################
# SECURITY GROUP
#############################

resource "aws_security_group" "qa_sg" {
  name        = "qa-environment-sg"
  description = "Allow SSH access"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################
# EC2 INSTANCE
#############################

resource "aws_instance" "qa_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = "qa-test-file"
  vpc_security_group_ids = [aws_security_group.qa_sg.id]

  tags = {
    Name = "qa-environment"
  }
}

#############################
# OUTPUT
#############################

output "vm_ip" {
  value = aws_instance.qa_vm.public_ip
}
