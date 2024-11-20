# We create a new instance

resource "aws_instance" "ec2_instance_web_server_2" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"

  # Different AZ
  subnet_id         = module.vpc.private_subnets[1]
  availability_zone = module.vpc.azs[1]
}

# Security group for the load balancer

resource "aws_security_group" "vpc_sg_allow_all_internet" {
  name        = "vpc_sg_allow_all_internet"
  description = "Allow HTTP inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_r_allow_all_internet_http" {
  security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_r_allow_all_internet_https" {
  security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}


# Application Load balancer


resource "aws_lb" "lb_web_server" {
  name               = "web-server-lb"
  internal           = false # Public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.vpc_sg_allow_all_internet.id]
  subnets            = module.vpc.private_subnets # In all the subnets and AZ

  enable_deletion_protection = true
}