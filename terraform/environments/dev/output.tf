output "vpc_id" {
  description = "ID of the environment VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_web_subnet_ids" {
  description = "Private Web subnet IDs"
  value       = module.vpc.private_web_subnet_ids
}

output "private_api_subnet_ids" {
  description = "Private API subnet IDs"
  value       = module.vpc.private_api_subnet_ids
}

output "private_data_subnet_ids" {
  description = "Private Data subnet IDs"
  value       = module.vpc.private_data_subnet_ids
}
output "security_group_ids" { value = module.security_groups.ids }
output "public_alb_dns_name" { value = module.alb.public_dns_name }
output "database_endpoint" { value = module.rds.endpoint }
output "database_master_secret_arn" { value = module.rds.master_secret_arn }
output "database_bootstrap_role_arn" { value = module.iam.database_bootstrap_role_arn }
output "github_deploy_role_arn" { value = module.iam.deploy_role_arn }
output "ecs_cluster_name" { value = module.compute.cluster_name }
output "ecs_service_names" { value = module.compute.service_names }
output "dashboard_name" { value = module.monitoring.dashboard_name }
output "budget_arn" { value = data.aws_budgets_budget.prerequisite.arn }
