# We create a new instance

resource "aws_instance" "ec2_instance_web_server_2" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"

  # Different AZ
  subnet_id         = module.vpc.private_subnets[1]
  availability_zone = module.vpc.azs[1]
  security_groups   = [aws_security_group.vpc_sg_allow_lb.id]

  user_data = <<EOT
#!/bin/bash
# This script will run on first start with sudo permissions
apt update
apt install -y httpd
systemctl start httpd
systemctl enable httpd
EOT
}

# Security group for the load balancer

resource "aws_security_group" "vpc_sg_allow_all_internet" {
  name        = "vpc_sg_allow_all_internet"
  description = "Allow HTTP and HTTPS inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_r_allow_all_internet_http" {
  description       = "Allow HTTP traffic from the internet"
  security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_r_allow_all_internet_https" {
  description       = "Allow HTTPS traffic from the internet"
  security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

#SG for allowing traffic to the instances from the Load Balancer
resource "aws_security_group" "vpc_sg_allow_lb" {
  name        = "vpc_sg_allow_lb"
  description = "Allow HTTP and HTTPS inbound traffic from Load Balancer SG"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_allow_lb_http" {
  description                  = "Allow HTTP traffic from load balancer"
  security_group_id            = aws_security_group.vpc_sg_allow_all_internet.id
  referenced_security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_allow_lb_https" {
  description                  = "Allow HTTPS traffic from load balancer"
  security_group_id            = aws_security_group.vpc_sg_allow_all_internet.id
  referenced_security_group_id = aws_security_group.vpc_sg_allow_all_internet.id
  from_port                    = 443
  ip_protocol                  = "tcp"
  to_port                      = 443
}


# Application Load balancer


resource "aws_lb" "lb_web_server" {
  name               = "web-server-lb"
  internal           = false # Public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.vpc_sg_allow_all_internet.id]
  subnets            = module.vpc.private_subnets # In all the subnets and AZ

  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true #Always true for ALB
}

# Target group for the 2 instances
resource "aws_lb_target_group" "lb_web_server_tg_instances" {
  name        = "web-server-lb-tf-instances"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled           = true
    interval          = 60 # seconds
    healthy_threshold = 3
    path              = "/"
    port              = "traffic-port" #Same port as above
    timeout           = 5              # seconds
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie" #Managed by the lb, can also be managed by the application
    cookie_duration = 86400       # One day
    # cookie_name = "sticky_cookie" #Must be specified if it is managed by the application
  }
  load_balancing_cross_zone_enabled = true # Enabled by default on ALB
}

# Now we attach both instances
resource "aws_lb_target_group_attachment" "lb_web_server_tg_attach_1" {
  target_group_arn = aws_lb_target_group.lb_web_server_tg_instances.arn
  target_id        = aws_instance.ec2_instance_web_server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "lb_web_server_tg_attach_2" {
  target_group_arn = aws_lb_target_group.lb_web_server_tg_instances.arn
  target_id        = aws_instance.ec2_instance_web_server_2.id
  port             = 80
}

# Listener for the target group
resource "aws_lb_listener" "lb_web_server_listener" {
  load_balancer_arn = aws_lb.lb_web_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    #This forwards the requests to the target group
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_web_server_tg_instances.arn
  }
}

# We can add rules to the listener
resource "aws_lb_listener_rule" "lb_web_server_listener_r" {
  listener_arn = aws_lb_listener.lb_web_server_listener.arn
  priority     = 100

  action {
    # We can formard to another target group, redirect or return a fixed response
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_web_server_tg_instances.arn
  }

  condition {
    path_pattern {
      values = ["/error/*"]
    }
  }

  condition {
    host_header {
      values = ["example.com"]
    }
  }
}


# Network Load Balancer


resource "aws_lb" "lb_network" {
  name               = "network-lb"
  internal           = false # Public
  load_balancer_type = "network"
  security_groups    = [aws_security_group.vpc_sg_allow_all_internet.id]
  # This will autoassign an IP per AZ
  subnets = module.vpc.private_subnets # In all the subnets and AZ

  enable_deletion_protection = true
}

# Target group for the 2 instances
resource "aws_lb_target_group" "lb_network_tg_instances" {
  name        = "network-lb-tf-instances"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled           = true
    interval          = 60 # seconds
    healthy_threshold = 3
    path              = "/"
    port              = "traffic-port" #Same port as above
    timeout           = 5              # seconds
  }
}

# Now we attach both instances
resource "aws_lb_target_group_attachment" "lb_network_tg_attach_1" {
  target_group_arn = aws_lb_target_group.lb_network_tg_instances.arn
  target_id        = aws_instance.ec2_instance_web_server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "lb_network_tg_attach_2" {
  target_group_arn = aws_lb_target_group.lb_network_tg_instances.arn
  target_id        = aws_instance.ec2_instance_web_server_2.id
  port             = 80
}

# Listener for the target group
resource "aws_lb_listener" "lb_network_listener" {
  load_balancer_arn = aws_lb.lb_web_server.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    #This forwards the requests to the target group
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_network_tg_instances.arn
  }
}