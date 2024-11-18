## LAUNCHING AN INSTANCE


## KEY PAIR SETUP


# We generate an SSH key for the Instance
resource "tls_private_key" "ssh_key_web_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair_web_server" {
  key_name   = "Key pair Web Server"
  public_key = tls_private_key.ssh_key_web_server.public_key_openssh
}


# VPC SETUP


# We create a VPC for the EC2 (More details on the vpc section)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "web-server-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# We create a basic Security Group

resource "aws_security_group" "vpc_sg_allow_ssh" {
  name        = "vpc_sg_allow_ssh"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_r_allow_ssh" {
  security_group_id = aws_security_group.vpc_sg_allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Egress is allowed to all of the internet by default
# resource "aws_vpc_security_group_egress_rule" "vpc_sg_r_allow_all_outbund" {
#   security_group_id = aws_security_group.vpc_sg_allow_ssh.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# }


# INSTANCE PROFILE CREATION


resource "aws_iam_instance_profile" "iam_instance_profile_web_server" {
  name = "Web-Server-Profile"
  # We created the role on the iam Section
  role = aws_iam_role.iam_role_ec2.name
}


# INSTANCE CREATION


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

  security_groups = [aws_security_group.vpc_sg_allow_ssh.id]

  user_data = <<EOT
#!/bin/bash
# This script will run on first start with sudo permissions
apt update
apt install -y httpd
systemctl start httpd
systemctl enable httpd
EOT

  # With this instance profile, the vm can assume the role and all its permissions
  iam_instance_profile = aws_iam_instance_profile.iam_instance_profile_web_server.name

  # Check Placement groups below
  placement_group = aws_placement_group.ec2_placement_group_web_server.id
  # placement_partition_number = "1"
}


# LAUNCH TEMPLATE

resource "aws_launch_template" "ec2_launch_template_web_server" {
  name = "Web-Server-Template"

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = 8
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.iam_instance_profile_web_server.name
  }

  ebs_optimized                        = true
  image_id                             = "ami-0664c8f94c2a2261b"
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t2.micro"
  key_name                             = aws_key_pair.ec2_key_pair_web_server.key_name
  vpc_security_group_ids               = [aws_security_group.vpc_sg_allow_ssh.id]

  network_interfaces {
    associate_public_ip_address = true
  }

  placement {
    availability_zone = "us-west-2a"
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


# LAUNCH TYPES


# SPOT INSTANCES


resource "aws_spot_instance_request" "cheap_worker" {
  ami           = "ami-0664c8f94c2a2261b"
  spot_price    = "0.03" # Max price
  instance_type = "t2.micro"
  spot_type     = "persistent"
  valid_from    = "2024-12-01T00:00:00-05:00"
  valid_until   = "2024-12-31T00:00:00-05:00"
}


# Capacity Reservation


resource "aws_ec2_capacity_reservation" "default" {
  instance_type     = "t2.micro"
  instance_platform = "Linux/UNIX"
  availability_zone = "us-east-1"
  instance_count    = 1
}


# ELASTIC IP


resource "aws_eip" "ec2_eip_web_server" {
  domain = "vpc"
}

resource "aws_eip_association" "ec2_eip_web_server_association" {
  instance_id        = aws_instance.ec2_instance_web_server.id
  allocation_id      = aws_eip.ec2_eip_web_server.id
  private_ip_address = aws_instance.ec2_instance_web_server.private_ip
}


# Placement Groups


resource "aws_placement_group" "ec2_placement_group_web_server" {
  name         = "Web-Server-PG"
  strategy     = "spread"
  spread_level = "rack" # host can be used on Outpost
  # partition_count = 7 # Only when the strategy is "partition"
}