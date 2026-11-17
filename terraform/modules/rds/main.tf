locals { name = "clinicflow-${var.environment}-aurora" }

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = var.subnet_ids
}

resource "aws_rds_cluster_parameter_group" "main" {
  name_prefix = "${local.name}-"
  family      = "aurora-mysql8.0"
  description = "Enforce TLS and database audit logging"
  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }
  parameter {
    name  = "server_audit_logging"
    value = "1"
  }
  parameter {
    name  = "server_audit_events"
    value = "CONNECT"
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_cloudwatch_log_group" "database" {
  for_each          = toset(["audit", "error"])
  name              = "/aws/rds/cluster/${local.name}/${each.key}"
  kms_key_id        = var.log_kms_key_arn
  retention_in_days = var.log_retention_days
}

resource "aws_rds_cluster" "main" {
  cluster_identifier                  = local.name
  engine                              = "aurora-mysql"
  engine_mode                         = "provisioned"
  engine_version                      = var.engine_version
  database_name                       = "clinicflow"
  master_username                     = "clinicflow_admin"
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.kms_key_arn
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  port                                = 3306
  db_subnet_group_name                = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids              = [var.security_group_id]
  backup_retention_period             = 7
  preferred_backup_window             = "16:00-17:00"
  preferred_maintenance_window        = "sun:18:00-sun:19:00"
  enabled_cloudwatch_logs_exports     = ["audit", "error"]
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.environment != "prod"
  final_snapshot_identifier           = "${local.name}-final"
  copy_tags_to_snapshot               = true
  delete_automated_backups            = var.environment != "prod"
  apply_immediately                   = false
  depends_on                          = [aws_cloudwatch_log_group.database]

  lifecycle {
    precondition {
      condition     = var.instance_count >= 1 && var.instance_count <= 2 && (var.environment != "prod" || (var.instance_count == 2 && var.deletion_protection))
      error_message = "Production requires two Aurora instances and deletion protection."
    }
  }
}

resource "aws_rds_cluster_instance" "main" {
  count                      = var.instance_count
  identifier                 = "${local.name}-${count.index + 1}"
  cluster_identifier         = aws_rds_cluster.main.id
  instance_class             = var.instance_class
  engine                     = aws_rds_cluster.main.engine
  engine_version             = aws_rds_cluster.main.engine_version
  db_subnet_group_name       = aws_db_subnet_group.main.name
  availability_zone          = var.availability_zones[count.index]
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  promotion_tier             = count.index
  copy_tags_to_snapshot      = true
}
