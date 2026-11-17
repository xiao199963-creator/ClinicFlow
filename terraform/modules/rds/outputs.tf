output "endpoint" { value = aws_rds_cluster.main.endpoint }
output "cluster_id" { value = aws_rds_cluster.main.id }
output "cluster_resource_id" { value = aws_rds_cluster.main.cluster_resource_id }
output "master_secret_arn" {
  description = "Metadata only. Never read secret_string through Terraform."
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}
output "instance_ids" { value = aws_rds_cluster_instance.main[*].id }
