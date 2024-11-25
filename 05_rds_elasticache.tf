# DB Instance

resource "aws_db_instance" "db_web_server" {
  identifier = "db-web-server"

  #Engine configuration
  engine               = "mysql"
  engine_version       = "8.0"
  parameter_group_name = "default.mysql8.0"

  instance_class = "db.t3.micro"
  db_name        = "ventas"
  username       = "admin"
  password       = var.db_password

  storage_type          = "gp2"
  allocated_storage     = 10
  max_allocated_storage = 100 #This enables Storage Autoscaling

  vpc_security_group_ids = [aws_security_group.vpc_sg_allow_db.id]
  skip_final_snapshot    = true
}

#SG for allowing traffic to the db from the instances
resource "aws_security_group" "vpc_sg_allow_db" {
  name        = "vpc_sg_allow_db"
  description = "Allow inbound traffic from instances to DB"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vpc_sg_allow_db_3306" {
  description                  = "Allow HTTP traffic from load balancer"
  security_group_id            = aws_security_group.vpc_sg_allow_db.id
  referenced_security_group_id = aws_security_group.vpc_sg_allow_lb.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}


resource "aws_elasticache_cluster" "cache_server" {
  cluster_id           = "cache-server"
  engine               = "redis" #Can be memcached
  node_type            = "cache.t3.micro"
  parameter_group_name = "default.memcached1.4"
  port                 = 6379
  availability_zone    = "us-east-1a"
}