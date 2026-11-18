output "repository_urls" { value = module.ecr.repository_urls }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.github.arn }
output "github_build_role_arn" { value = aws_iam_role.github_build.arn }
output "audit_trail_arn" { value = module.audit.trail_arn }
output "audit_bucket_name" { value = module.audit.bucket_name }
