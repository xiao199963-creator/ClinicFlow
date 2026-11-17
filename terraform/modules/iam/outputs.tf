output "execution_role_arns" { value = { for tier, role in aws_iam_role.execution : tier => role.arn } }
output "task_role_arns" { value = { for tier, role in aws_iam_role.task : tier => role.arn } }
output "deploy_role_arn" { value = aws_iam_role.deploy.arn }
output "database_bootstrap_role_arn" { value = aws_iam_role.database_bootstrap.arn }
