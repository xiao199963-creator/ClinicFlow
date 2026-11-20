locals {
  prefix = "clinicflow-${var.environment}"
  ecs_metrics = merge([
    for tier in ["web", "api"] : {
      for metric in ["CPUUtilization", "MemoryUtilization"] : "${tier}-${metric}" => {
        metric = metric
        tier   = tier
      }
    }
  ]...)
}
resource "aws_sns_topic" "alarms" {
  name              = "${local.prefix}-alarms"
  kms_master_key_id = var.data_kms_key_arn
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
resource "aws_sns_topic_policy" "alarms" {
  arn = aws_sns_topic.alarms.arn
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Sid       = "CloudWatchPublish"
    Effect    = "Allow"
    Principal = { Service = "cloudwatch.amazonaws.com" }
    Action    = "sns:Publish"
    Resource  = aws_sns_topic.alarms.arn
    Condition = {
      StringEquals = { "aws:SourceAccount" = var.account_id }
      ArnLike      = { "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${var.account_id}:alarm:${local.prefix}-*" }
    }
  }] })
}
resource "aws_cloudwatch_metric_alarm" "ecs" {
  for_each            = local.ecs_metrics
  alarm_name          = "${local.prefix}-${each.key}"
  namespace           = "AWS/ECS"
  metric_name         = each.value.metric
  dimensions          = { ClusterName = var.cluster_name, ServiceName = var.service_names[each.value.tier] }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
resource "aws_cloudwatch_metric_alarm" "healthy_targets" {
  for_each            = var.load_balancer_arn_suffixes
  alarm_name          = "${local.prefix}-${each.key}-healthy-targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { LoadBalancer = each.value, TargetGroup = var.target_group_arn_suffixes[each.key] }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = var.desired_count
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
resource "aws_cloudwatch_metric_alarm" "target_errors" {
  for_each            = var.load_balancer_arn_suffixes
  alarm_name          = "${local.prefix}-${each.key}-target-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = each.value, TargetGroup = var.target_group_arn_suffixes[each.key] }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${local.prefix}-database-cpu"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBClusterIdentifier = var.database_cluster_id }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
resource "aws_cloudwatch_metric_alarm" "database_memory" {
  alarm_name          = "${local.prefix}-database-free-memory"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  dimensions          = { DBClusterIdentifier = var.database_cluster_id }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 268435456
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/clinicflow/${var.environment}/vpc-flow"
  kms_key_id        = var.log_kms_key_arn
  retention_in_days = var.log_retention_days
}
resource "aws_iam_role" "flow" {
  name = "${local.prefix}-vpc-flow-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow"
    Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    Action    = "sts:AssumeRole"
    Condition = {
      StringEquals = { "aws:SourceAccount" = var.account_id }
      ArnLike      = { "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${var.account_id}:vpc-flow-log/*" }
    }
  }] })
}
resource "aws_iam_role_policy" "flow" {
  role = aws_iam_role.flow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"], Resource = var.log_kms_key_arn,
      Condition = { StringEquals = {
        "kms:ViaService"                     = "logs.${var.aws_region}.amazonaws.com"
        "kms:EncryptionContext:aws:logs:arn" = aws_cloudwatch_log_group.flow.arn
      } }
    },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow.arn}:*" },
    { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" }
  ] })
}
resource "aws_flow_log" "main" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow.arn
  iam_role_arn             = aws_iam_role.flow.arn
  max_aggregation_interval = 60
  depends_on               = [aws_iam_role_policy.flow]
}
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.prefix
  dashboard_body = jsonencode({ widgets = concat([
    for index, tier in ["web", "api"] : {
      type = "metric", x = index * 12, y = 0, width = 12, height = 6
      properties = {
        title   = "${tier} CPU and memory", region = var.aws_region, stat = "Average", period = 60
        metrics = [for metric in ["CPUUtilization", "MemoryUtilization"] : ["AWS/ECS", metric, "ClusterName", var.cluster_name, "ServiceName", var.service_names[tier]]]
      }
    }
    ], [
    for index, tier in ["web", "api"] : {
      type = "metric", x = index * 12, y = 6, width = 12, height = 6
      properties = {
        title   = "${tier} target health", region = var.aws_region, stat = "Minimum", period = 60
        metrics = [["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.load_balancer_arn_suffixes[tier], "TargetGroup", var.target_group_arn_suffixes[tier]]]
      }
    }
    ], [{
      type = "metric", x = 0, y = 12, width = 12, height = 6
      properties = {
        title   = "Aurora CPU", region = var.aws_region, stat = "Average", period = 60
        metrics = [["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.database_cluster_id]]
      }
  }]) })
}
