locals {
  tags = {
    Terraform   = "true"
    Environment = "dev"
    Edvinas     = "true"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name                          = "eks-vpc"
  cidr                          = "10.3.0.0/16"
  manage_default_security_group = false
  manage_default_route_table    = false
  manage_default_network_acl    = false

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24"]
  tags            = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"

  name = "eks-cluster"

  control_plane_subnet_ids     = module.vpc.private_subnets
  subnet_ids                   = module.vpc.private_subnets
  create_cloudwatch_log_group  = false
  enable_irsa                  = false
  vpc_id                       = module.vpc.vpc_id
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  tags = local.tags
}
