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
  ttl     = 300
  records = [aws_instance.ec2_instance_web_server.public_ip]
  #Simple routing policy
}