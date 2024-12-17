## Main VPC Creation


resource "aws_vpc" "vpc_main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default" #Can be dedicated but it is more expensive
}

#We can add mor CIDR blocks to our VPC
resource "aws_vpc_ipv4_cidr_block_association" "vpc_main_secondary_cidr" {
  vpc_id     = aws_vpc.vpc_main.id
  cidr_block = "10.1.0.0/16"
}

#Public Subnet
resource "aws_subnet" "vpc_main_public_subnet" {
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true #Auto assign public IPs for EC2 instances launched on this subnet
}

#Private subnets
resource "aws_subnet" "vpc_main_private_subnet_1" {
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "vpc_main_private_subnet_2" {
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "us-east-1b"
}


# Public Internet connectivity



resource "aws_internet_gateway" "main_igw" {
  #   vpc_id = aws_vpc.vpc_main.id     # An internet gateway is not neccesarily connected to a VPC
}

# Now we attach it to the VPC
resource "aws_internet_gateway_attachment" "main_igw_vpc" {
  internet_gateway_id = aws_internet_gateway.main_igw.id
  vpc_id              = aws_vpc.vpc_main.id
}

#Route table
resource "aws_route_table" "main_vpc_public_route_table" {
  vpc_id = aws_vpc.vpc_main.id
}

resource "aws_route_table" "main_vpc_private_route_table" {
  vpc_id = aws_vpc.vpc_main.id
}

#We associate the subnets with the Route Tables
resource "aws_route_table_association" "main_vpc_public_route_table_public_subnet" {
  subnet_id      = aws_subnet.vpc_main_public_subnet.id
  route_table_id = aws_route_table.main_vpc_public_route_table.id
}

resource "aws_route_table_association" "main_vpc_private_route_table_private_subnet_1" {
  subnet_id      = aws_subnet.vpc_main_private_subnet_1.id
  route_table_id = aws_route_table.main_vpc_private_route_table.id
}

resource "aws_route_table_association" "main_vpc_private_route_table_private_subnet_2" {
  subnet_id      = aws_subnet.vpc_main_private_subnet_1.id
  route_table_id = aws_route_table.main_vpc_private_route_table.id
}

#Routes
resource "aws_route" "main_vpc_public_route_table_igw_route" {
  route_table_id         = aws_route_table.main_vpc_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"                      #Every IP
  gateway_id             = aws_internet_gateway.main_igw.id # Goes to the Internet Gateway
}


# BASTION HOSTS


resource "aws_instance" "ec2_instance_bastion_host" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"

  subnet_id         = aws_subnet.vpc_main_public_subnet.id
  availability_zone = aws_subnet.vpc_main_public_subnet.availability_zone
  security_groups   = [aws_security_group.sg_bastion_host.id]
}

resource "aws_security_group" "sg_bastion_host" {
  name        = "bastion_host"
  description = "Allow SSH access from the internet to the bastion host"
  vpc_id      = aws_vpc.vpc_main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Private instance
resource "aws_instance" "ec2_instance_private_instance" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"

  subnet_id         = aws_subnet.vpc_main_private_subnet_1.id
  availability_zone = aws_subnet.vpc_main_private_subnet_1.availability_zone
  security_groups   = [aws_security_group.sg_bastion_host.id]
}

resource "aws_security_group" "sg_private_instances" {
  name        = "private_instance"
  description = "Allow SSH access from the bastion host"
  vpc_id      = aws_vpc.vpc_main.id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_bastion_host.id]
  }
}


# NAT Gateway


# NAT gateway in the public subnet
resource "aws_nat_gateway" "main_natgw" {
  subnet_id = aws_subnet.vpc_main_public_subnet.id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main_igw]
}

#Traffic from the EC2 instances in the private subnet goes to the NAT Gateway
resource "aws_route" "main_vpc_private_route_table_natgw_route" {
  route_table_id         = aws_route_table.main_vpc_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"                   #Every IP
  nat_gateway_id         = aws_nat_gateway.main_natgw.id # Goes to the INAT Gateway
}


# VPC Peering


resource "aws_vpc_peering_connection" "main_vpc_peering" {
  peer_vpc_id = aws_vpc.vpc_main.id
  vpc_id      = module.vpc.vpc_id
}


# VPC Endpoint


resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.vpc_main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.main_vpc_private_route_table.id]
}