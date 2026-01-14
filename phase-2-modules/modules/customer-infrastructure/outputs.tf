output "public_ip" {
  value = module.ec2_instance.public_ip
}

output "ssh_command" {
  value = "ssh ec2-user@${module.ec2_instance.public_ip}"
}

output "postgres_fqdn" {
  value = module.rds.db_instance_address
}
