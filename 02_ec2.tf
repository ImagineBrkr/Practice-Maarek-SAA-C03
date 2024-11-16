## LAUNCHING AN INSTANCE


# We generate an SSH key for the Instance
resource "tls_private_key" "ssh_key_web_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair_web_server" {
  key_name   = "Key pair Web Server"
  public_key = tls_private_key.ssh_key_web_server.public_key_openssh
}

# We create a VPC for the EC2 (More details on the vpc section)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "web-server-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

resource "aws_instance" "ec2_instance_web_server" {
  # ami are specific to the region
  # https://cloud-images.ubuntu.com/locator/ec2/
  # This uses Ubuntu 22.04
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro" # Free tier eligible 1 vCpu 1Gb RAM  

  key_name = aws_key_pair.ec2_key_pair_web_server.key_name

  # Automatically allocate a public ip (It has a cost)
  associate_public_ip_address = true
  subnet_id                   = module.vpc.private_subnets[0]
  availability_zone           = module.vpc.azs[0]

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_type           = "gp2"
    volume_size           = 8
  }
  user_data = <<EOT
#!/bin/bash
# This script will run on first start with sudo permissions
apt update
apt install -y httpd
systemctl start httpd
systemctl enable httpd
EOT
}