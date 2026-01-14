variable "customer_name" {
  description = "Name of the customer (used for resource naming)"
  type        = string
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the customer's virtual network"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "ec2-user"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "postgres_admin_password" {
  description = "Admin password for PostgreSQL"
  type        = string
  sensitive   = true
}
