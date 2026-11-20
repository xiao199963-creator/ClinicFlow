output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = { for k, subnet in aws_subnet.public : k => subnet.id }
}

output "private_web_subnet_ids" {
  description = "Private subnet IDs for Web ECS tasks"
  value       = { for k, subnet in aws_subnet.private_web : k => subnet.id }
}

output "private_api_subnet_ids" {
  description = "Private subnet IDs for API ECS tasks"
  value       = { for k, subnet in aws_subnet.private_api : k => subnet.id }
}

output "private_data_subnet_ids" {
  description = "Private subnet IDs for Aurora MySQL"
  value       = { for k, subnet in aws_subnet.private_data : k => subnet.id }
}
output "private_route_table_ids" {
  value = concat([aws_route_table.private_web.id, aws_route_table.private_api.id, aws_route_table.private_data.id], aws_route_table.private_web_b[*].id, aws_route_table.private_api_b[*].id)
}
