output "repository_urls" { value = { for name, repo in aws_ecr_repository.main : name => repo.repository_url } }
output "repository_arns" { value = { for name, repo in aws_ecr_repository.main : name => repo.arn } }

output "shared_kms_key_arn" { value = aws_kms_key.ecr.arn }
