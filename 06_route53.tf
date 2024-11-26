#Hosted zone


#Private because we don't have a domain
resource "aws_route53_zone" "r53_zone_my_server" {
  name = "my-server.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

#Record for an IPv4
resource "aws_route53_record" "r53_domain_my_server" {
  zone_id = aws_route53_zone.r53_zone_my_server.zone_id
  name    = "api.my-server.internal"
  type    = "A"
  ttl     = 300 # Seconds
  # There can be multiple records, since there is no routing policy, the client will chose one randomly
  records = [aws_instance.ec2_instance_web_server.public_ip, aws_instance.ec2_instance_web_server_2.public_ip]
  #Simple routing policy
}

#Record for a DNS
resource "aws_route53_record" "r53_domain_my_server_elb" {
  zone_id = aws_route53_zone.r53_zone_my_server.zone_id
  name    = "elb.my-server.internal"
  type    = "CNAME"
  ttl     = 300 # Seconds
  records = [aws_lb.lb_web_server.dns_name]
  #Simple routing policy
}

# Record for an alias
resource "aws_route53_record" "r53_domain_my_server_elb_alias" {
  zone_id = aws_route53_zone.r53_zone_my_server.zone_id
  name    = "my-server.internal"
  type    = "A"

  alias {
    name                   = aws_lb.lb_web_server.dns_name
    zone_id                = aws_lb.lb_web_server.zone_id
    evaluate_target_health = true
  }
}


# HEALTH CHECKS

resource "aws_route53_health_check" "r53_healthcheck_web_server" {
  ip_address        = aws_instance.ec2_instance_web_server.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"
  # region = ["us-east-1", "us-east-2"] # You can specify the regions, or use all of them
}

#Weighted routing
resource "aws_route53_record" "r53_domain_my_server_weighted_1" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "weighted.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]

  weighted_routing_policy {
    weight = 10
  }
}

resource "aws_route53_record" "r53_domain_my_server_weighted_2" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "weighted.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev_2"
  records        = [aws_instance.ec2_instance_web_server_2.public_ip]

  weighted_routing_policy {
    weight = 10
  }
}

#Latency based routing
resource "aws_route53_record" "r53_domain_my_server_latency" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "latency.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]

  latency_routing_policy {
    region = "us-east-1" # The routing is based on the region with the less latency for the user
  }
}

#Failover routing
resource "aws_route53_record" "r53_domain_my_server_failover" {
  zone_id         = aws_route53_zone.r53_zone_my_server.zone_id
  name            = "failover.my-server.internal"
  type            = "A"
  ttl             = 5
  set_identifier  = "dev"
  records         = [aws_instance.ec2_instance_web_server.public_ip]
  health_check_id = aws_route53_health_check.r53_healthcheck_web_server.id

  failover_routing_policy {
    type = "PRIMARY" # The principal record, if it fails, it goes to the SECONDARY
  }
}

resource "aws_route53_record" "r53_domain_my_server_failover_secondary" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "failover.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev_2"
  records        = [aws_instance.ec2_instance_web_server_2.public_ip]

  failover_routing_policy {
    type = "SECONDARY"
  }
}

#Geolocation based routing
resource "aws_route53_record" "r53_domain_my_server_geolocation" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "geolocation.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]

  geolocation_routing_policy {
    country = "*" # Default
  }
}

#Geolocation based routing
resource "aws_route53_record" "r53_domain_my_server_geolocation_pe" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "geolocation.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev_2"
  records        = [aws_instance.ec2_instance_web_server_2.public_ip]

  geolocation_routing_policy {
    continent = "SA"
    country   = "PE" # Only for peruvians
  }
}

#Geoproximity based routing
resource "aws_route53_record" "r53_domain_my_server_geoproximity" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "geoproximity.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]

  geoproximity_routing_policy {
    aws_region = "us-east-1"
    bias       = 90 #Higher bias means even the traffic closer to another region, may be redirected to this region.
  }
}

#IP based routing
resource "aws_route53_cidr_collection" "r53_cidr_collection_main_office" {
  name = "main-office"
}

resource "aws_route53_cidr_location" "r53_cidr_location_main_office" {
  cidr_collection_id = aws_route53_cidr_collection.r53_cidr_collection_main_office.id
  name               = "office"
  cidr_blocks        = ["200.5.3.0/24", "200.6.3.0/24"]
}

resource "aws_route53_record" "r53_domain_my_server_ip" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "ip-based.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]

  #The client's IP in these ranges will be routed to this record.
  cidr_routing_policy {
    collection_id = aws_route53_cidr_collection.r53_cidr_collection_main_office.id
    location_name = aws_route53_cidr_location.r53_cidr_location_main_office.name
  }
}

#Multi-value policy
resource "aws_route53_record" "r53_domain_my_server_multi_1" {
  zone_id        = aws_route53_zone.r53_zone_my_server.zone_id
  name           = "multi.my-server.internal"
  type           = "A"
  ttl            = 5
  set_identifier = "dev"
  records        = [aws_instance.ec2_instance_web_server.public_ip]
  #Will return multiple records, but only the healthy ones.
  health_check_id                  = aws_route53_health_check.r53_healthcheck_web_server.id
  multivalue_answer_routing_policy = true
}

resource "aws_route53_record" "r53_domain_my_server_multi_2" {
  zone_id                          = aws_route53_zone.r53_zone_my_server.zone_id
  name                             = "multi.my-server.internal"
  type                             = "A"
  ttl                              = 5
  set_identifier                   = "dev_2"
  records                          = [aws_instance.ec2_instance_web_server_2.public_ip]
  multivalue_answer_routing_policy = true
}

