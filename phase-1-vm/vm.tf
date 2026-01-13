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

  name                          = "vpc-demo"
  cidr                          = "10.3.0.0/16"
  manage_default_security_group = false
  manage_default_route_table    = false
  manage_default_network_acl    = false

  azs            = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets = ["10.3.1.0/24"]
  tags           = local.tags
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "ec2-demo"

  instance_type         = "t3.micro"
  key_name              = aws_key_pair.awsuser.key_name
  subnet_id             = module.vpc.public_subnets[0]
  create_eip            = true
  create_security_group = true
  security_group_ingress_rules = {
    ssh_rule = {
      cidr_ipv4 = "0.0.0.0/0"
      from_port = 22
      to_port   = 22
    }
  }

  tags = local.tags
}

resource "aws_key_pair" "awsuser" {
  key_name = "awsuser"
  # Make sure that you have the public key in your ~/.ssh/id_rsa.pub
  public_key = file("~/.ssh/id_rsa.pub")
}
