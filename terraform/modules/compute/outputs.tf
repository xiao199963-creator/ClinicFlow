output "cluster_name" { value = aws_ecs_cluster.main.name }
output "service_names" { value = { for tier, service in aws_ecs_service.main : tier => service.name } }
output "task_definition_arns" { value = { for tier, task in aws_ecs_task_definition.main : tier => task.arn } }
