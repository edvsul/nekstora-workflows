terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  profile = "tgtg-playground-edvinas"
}


# Customer 1: CATO Corporation
module "cato" {
  source = "./modules/customer-infrastructure"

  customer_name           = "cato"
  region                  = "eu-west-1"
  vpc_cidr                = "10.1.0.0/16"
  ssh_public_key          = file("~/.ssh/id_rsa.pub")
  postgres_admin_password = "CatoP@ssw0rd123!"
}

# Customer 2: Cicero Ltd
module "cicero" {
  source = "./modules/customer-infrastructure"

  customer_name           = "cicero"
  region                  = "eu-west-1"
  vpc_cidr                = "10.2.0.0/16"
  ssh_public_key          = file("~/.ssh/id_rsa.pub")
  postgres_admin_password = "CiceroP@ssw0rd123!"
}

# Outputs for Customer 1
output "cato_vm_ip" {
  description = "CATO VM public IP"
  value       = module.cato.public_ip
}

output "cato_ssh" {
  description = "CATO SSH connection"
  value       = module.cato.ssh_command
}

output "cato_postgres" {
  description = "CATO PostgreSQL FQDN"
  value       = module.cato.postgres_fqdn
}
