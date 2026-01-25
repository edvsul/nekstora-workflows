output "db_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "db_instance_name" {
  value = module.rds.db_instance_name
}

output "db_instance_username" {
  value     = module.rds.db_instance_username
  sensitive = true
}
