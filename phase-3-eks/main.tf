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
  ebs_csi_service_account_namespace = "kube-system"
  ebs_csi_service_account_name      = "ebs-csi-controller-sa"
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
      principal_arn = var.iam_role_arn # The placeholder for your IAM role ARN to run kubectl commands
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
    coredns    = {}
    kube-proxy = {}
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
