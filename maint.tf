terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "existing-vpc" {
  filter {
    name = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

data "aws_instance" "existing-ec2" {
  filter {
    name = "tag:Name"
    values = [var.existing_instance_name]
  }
}

data "aws_security_group" "existing_sg" {
  filter {
    name = "tag:Name"
    values = [var.existing_security_group_name]
  }
}

resource "random_string" "aws_instance_name" {
  length  = 6
  special = false
}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048

  provisioner "local-exec" {
    command = "rm -f ${var.key_name}.pem"
  }
  provisioner "local-exec" {
    command = "echo '${tls_private_key.main.private_key_pem}' > ${var.key_name}.pem"
  }
}

resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = tls_private_key.main.public_key_openssh
}

resource "aws_instance" "main" {
  ami           = data.aws_instance.existing-ec2.ami
  instance_type = data.aws_instance.existing-ec2.instance_type
  subnet_id     = data.aws_instance.existing-ec2.subnet_id
  key_name      = aws_key_pair.main.key_name
  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]
  tags = {
    Name       = "stackc-v3-simple-ec2-insatnce-${random_string.aws_instance_name.result}"
    can_delete = "true"
    key_name   = aws_key_pair.main.key_name
    time = timestamp()
  }
}

resource "null_resource" "private-key-permission-update" {
  depends_on = [aws_instance.main]
  provisioner "local-exec" {
    command = "chmod 400 ${var.key_name}.pem"
  }
}
