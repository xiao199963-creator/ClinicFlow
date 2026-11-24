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
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "log_output"
    value = "FILE"
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_cloudwatch_log_group" "database" {
  for_each          = toset(["audit", "error", "slowquery"])
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
  backup_retention_period             = var.backup_retention_days
  preferred_backup_window             = "16:00-17:00"
  preferred_maintenance_window        = "sun:18:00-sun:19:00"
  enabled_cloudwatch_logs_exports     = ["audit", "error", "slowquery"]
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.final_snapshot_identifier
  copy_tags_to_snapshot               = true
  delete_automated_backups            = var.delete_automated_backups
  apply_immediately                   = false
  depends_on                          = [aws_cloudwatch_log_group.database]

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverlessv2_scaling == null ? [] : [var.serverlessv2_scaling]
    content {
      min_capacity             = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity             = serverlessv2_scaling_configuration.value.max_capacity
      seconds_until_auto_pause = serverlessv2_scaling_configuration.value.min_capacity == 0 ? serverlessv2_scaling_configuration.value.seconds_until_auto_pause : null
    }
  }

  lifecycle {
    precondition {
      condition     = contains([1, 2], var.instance_count) && ((var.instance_class == "db.serverless") == (var.serverlessv2_scaling != null))
      error_message = "Use one writer or a writer and reader; db.serverless requires a scaling configuration, provisioned instances must omit it."
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
