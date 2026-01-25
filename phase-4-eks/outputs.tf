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

output "db_credentials_secret_arn" {
  value = module.secrets-manager.secret_arn
}

output "db_credentials_secret_name" {
  value = module.secrets-manager.secret_name
}
