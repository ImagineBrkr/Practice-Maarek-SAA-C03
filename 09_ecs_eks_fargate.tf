# ECS Cluster

resource "aws_ecs_cluster" "ecs_cluster_production" {
  name = "production-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_production_cp" {
  cluster_name = aws_ecs_cluster.ecs_cluster_production.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# EKS

resource "aws_eks_cluster" "eks_cluster_production" {
  name = "production-eks-cluster"

  role_arn = aws_iam_role.eks_cluster_production_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }
}

resource "aws_iam_role" "eks_cluster_production_role" {
  name = "eks-cluster-production-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = [
            "eks.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
      },
    ]
  })
}