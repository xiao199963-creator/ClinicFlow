output "vpc_id" {
  description = "ID of the dev VPC"
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