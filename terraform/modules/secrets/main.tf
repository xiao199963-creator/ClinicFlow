locals {
  root_arn = "arn:aws:iam::${var.account_id}:root"
  delegation = {
    Sid       = "EnableAccountIAM"
    Effect    = "Allow"
    Principal = { AWS = local.root_arn }
    Action    = "kms:*"
    Resource  = "*"
  }
}

resource "aws_kms_key" "data" {
  description             = "ClinicFlow ${var.environment} database, Secrets Manager and SNS"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_days
  policy = jsonencode({ Version = "2012-10-17", Statement = [local.delegation, {
    Sid       = "CloudWatchAlarmNotifications"
    Effect    = "Allow"
    Principal = { Service = "cloudwatch.amazonaws.com" }
    Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
    Resource  = "*"
    Condition = {
      StringEquals = { "aws:SourceAccount" = var.account_id }
      ArnLike      = { "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${var.account_id}:alarm:clinicflow-${var.environment}-*" }
    }
  }] })
}

resource "aws_kms_key" "logs" {
  description             = "ClinicFlow ${var.environment} CloudWatch encryption"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_days
  policy = jsonencode({ Version = "2012-10-17", Statement = [local.delegation, {
    Sid       = "CloudWatchLogs"
    Effect    = "Allow"
    Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
    Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    Resource  = "*"
    Condition = { ArnLike = { "kms:EncryptionContext:aws:logs:arn" = [
      "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/clinicflow/${var.environment}/*",
      "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/rds/cluster/clinicflow-${var.environment}-aurora/*"
    ] } }
  }] })
}

resource "aws_kms_alias" "data" {
  name          = "alias/clinicflow/${var.environment}/data"
  target_key_id = aws_kms_key.data.key_id
}
resource "aws_kms_alias" "logs" {
  name          = "alias/clinicflow/${var.environment}/logs"
  target_key_id = aws_kms_key.logs.key_id
}

# Additional required alias on the existing data key; no encrypted resource is replaced.
resource "aws_kms_alias" "environment" {
  name          = "alias/clinicflow-${var.environment}"
  target_key_id = aws_kms_key.data.key_id
}
