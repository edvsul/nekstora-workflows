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
  enable_nat_gateway            = true

  azs             = ["eu-west-1a", "eu-west-1b"]
  public_subnets  = ["10.3.0.0/24"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24"]
  tags            = local.tags
}

locals {
  ebs_csi_service_account_namespace         = "kube-system"
  ebs_csi_service_account_name              = "ebs-csi-controller-sa"
  secrets_manager_service_account_namespace = "kube-system" # Namespace where n8n will run
  secrets_manager_service_account_name      = "secrets-manager-controller-sa"
}

module "ebs_csi_irsa_role" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.11.1"
  create_role                   = true
  role_name                     = "eks-cluster-ebs-csi-controller"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.ebs_csi_service_account_namespace}:${local.ebs_csi_service_account_name}"]
}

module "secrets_manager_irsa_role" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.11.1"
  create_role                   = true
  role_name                     = "eks-cluster-secrets-manager"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.secrets_manager_service_account_namespace}:${local.secrets_manager_service_account_name}"]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"

  name               = "eks-cluster"
  kubernetes_version = "1.34"

  control_plane_subnet_ids     = module.vpc.private_subnets
  subnet_ids                   = module.vpc.private_subnets
  create_cloudwatch_log_group  = false
  enable_irsa                  = true
  vpc_id                       = module.vpc.vpc_id
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  access_entries = {
    sso_admin = {
      principal_arn = var.iam_role_arn # The placeholder for your IAM role ARN to run kubectl commands. Set with TF_VAR_iam_role_arn
      type          = "STANDARD"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  addons = {
    vpc-cni = {
      before_compute = true # Make sure VPC CNI is installed before compute nodes are created. Otherwise node health status will fail
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
    coredns                               = {}
    kube-proxy                            = {}
    aws-secrets-store-csi-driver-provider = {}
  }

  eks_managed_node_groups = {
    first_node_group = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
      iam_role_additional_policies = {
        ebs_csi_driver = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.0"

  identifier = "psql-rds"

  engine               = "postgres"
  engine_version       = "17.4"
  family               = "postgres17"
  major_engine_version = "17"
  instance_class       = "db.t3.micro"

  allocated_storage     = 32
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name                     = "customerdb"
  username                    = "psqladmin"
  manage_master_user_password = false
  password_wo                 = "n8n-password"
  password_wo_version         = "1"
  create_db_subnet_group      = true
  db_subnet_group_name        = "psql-subnet-group"
  vpc_security_group_ids      = [module.rds_security_group.security_group_id]
  subnet_ids                  = module.vpc.private_subnets

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = false
  skip_final_snapshot = true
  parameters = [
    {
      name  = "rds.force_ssl" # Disable SSL
      value = "0"
    }
  ]

  tags = local.tags
}

module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "psql-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

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

module "secrets-manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.1.0"

  name                    = "db-credentials"
  recovery_window_in_days = 0

  secret_string = jsonencode({
    db_host     = module.rds.db_instance_endpoint
    db_name     = module.rds.db_instance_name
    db_user     = module.rds.db_instance_username
    db_password = "n8n-password"
  })

  description = "Database connection details"

  tags = local.tags
}
