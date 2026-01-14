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
  cidr                          = var.vpc_cidr
  manage_default_security_group = false
  manage_default_route_table    = false
  manage_default_network_acl    = false

  azs                = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets    = [cidrsubnet(var.vpc_cidr, 8, 2), cidrsubnet(var.vpc_cidr, 8, 3)]
  public_subnets     = [cidrsubnet(var.vpc_cidr, 8, 1)]
  enable_nat_gateway = true
  enable_vpn_gateway = false
  tags               = local.tags
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "vm-${var.customer_name}"

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
  key_name = "awsuser-${var.customer_name}"
  # Make sure that you have the public key in your ~/.ssh/id_rsa.pub
  public_key = var.ssh_public_key
  tags       = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "psql-${var.customer_name}"

  # Database configuration
  engine               = "postgres"
  engine_version       = "17.4"
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = "db.t3.micro"

  # Storage configuration
  allocated_storage     = 32
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  # Database credentials
  db_name  = "customerdb"
  username = "psqladmin"
  password = var.postgres_admin_password

  # Network configuration
  create_db_subnet_group = true
  db_subnet_group_name   = "psql-${var.customer_name}-subnet-group"
  vpc_security_group_ids = [module.rds_security_group.security_group_id]
  subnet_ids             = module.vpc.private_subnets

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Disable deletion protection for demo
  deletion_protection = false
  skip_final_snapshot = true

  tags = local.tags
}

# Security Group for RDS using terraform-aws-modules/security-group/aws
module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "psql-${var.customer_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  # Ingress rules
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

  # Egress rules
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}
