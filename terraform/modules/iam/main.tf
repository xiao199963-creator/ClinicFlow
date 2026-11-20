locals {
  prefix               = "clinicflow-${var.environment}"
  task_definition_arns = [for tier in ["web", "api"] : "arn:aws:ecs:${var.aws_region}:${var.account_id}:task-definition/${local.prefix}-${tier}:*"]
  ecs_trust = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow"
    Principal = { Service = "ecs-tasks.amazonaws.com" }
    Action    = "sts:AssumeRole"
    Condition = {
      StringEquals = { "aws:SourceAccount" = var.account_id }
      ArnLike      = { "aws:SourceArn" = "arn:aws:ecs:${var.aws_region}:${var.account_id}:*" }
    }
  }] })
}

resource "aws_iam_role" "execution" {
  for_each           = toset(["web", "api"])
  name               = "${local.prefix}-${each.key}-execution"
  assume_role_policy = local.ecs_trust
}
resource "aws_iam_role_policy" "execution" {
  for_each = aws_iam_role.execution
  role     = each.value.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"], Resource = var.repository_arns[each.key] },
    { Effect = "Allow", Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*"], Resource = var.log_kms_key_arn,
      Condition = { StringEquals = {
        "kms:ViaService"                     = "logs.${var.aws_region}.amazonaws.com"
        "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/clinicflow/${var.environment}/${each.key}"
      } }
    },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/clinicflow/${var.environment}/${each.key}:*" }
  ] })
}
resource "aws_iam_role" "task" {
  for_each           = toset(["web", "api"])
  name               = "${local.prefix}-${each.key}-task"
  assume_role_policy = local.ecs_trust
}
# Web has no AWS permissions. API can authenticate only as its application DB user.
resource "aws_iam_role_policy" "api_database" {
  role = aws_iam_role.task["api"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect   = "Allow"
    Action   = ["rds-db:connect"]
    Resource = "arn:aws:rds-db:${var.aws_region}:${var.account_id}:dbuser:${var.db_cluster_resource_id}/clinicflow_app"
  }] })
}

# Phase 1 uses a private MySQL client operated by a designated administrator.
resource "aws_iam_role" "database_bootstrap" {
  name = "${local.prefix}-database-bootstrap"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { AWS = var.bootstrap_operator_role_arn }
  }] })
}
resource "aws_iam_role_policy" "database_bootstrap" {
  role = aws_iam_role.database_bootstrap.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.master_secret_arn },
    { Effect = "Allow", Action = ["kms:Decrypt"], Resource = var.data_kms_key_arn,
    Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com", "kms:EncryptionContext:SecretARN" = var.master_secret_arn } } }
  ] })
}

resource "aws_iam_role" "deploy" {
  name = "${local.prefix}-github-deploy"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow"
    Principal = { Federated = var.oidc_provider_arn }
    Action    = "sts:AssumeRoleWithWebIdentity"
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${var.environment}"
    } }
  }] })
}
resource "aws_iam_role_policy" "deploy" {
  role = aws_iam_role.deploy.id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat([
    { Effect = "Allow", Action = "ecs:DescribeServices", Resource = [for tier in ["web", "api"] : "arn:aws:ecs:${var.aws_region}:${var.account_id}:service/${local.prefix}/${local.prefix}-${tier}"] },
    # DescribeTaskDefinition does not support resource-level permissions.
    { Effect = "Allow", Action = "ecs:DescribeTaskDefinition", Resource = "*" },
    { Effect = "Allow", Action = "ecs:RegisterTaskDefinition", Resource = local.task_definition_arns,
    Condition = { StringEquals = { "aws:RequestTag/Project" = "clinicflow", "aws:RequestTag/Environment" = var.environment } } },
    { Effect = "Allow", Action = "ecs:TagResource", Resource = local.task_definition_arns,
    Condition = { StringEquals = { "ecs:CreateAction" = "RegisterTaskDefinition" } } },
    { Effect = "Allow", Action = "iam:PassRole", Resource = concat(values(aws_iam_role.execution)[*].arn, values(aws_iam_role.task)[*].arn),
    Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } }
    ], [for tier in ["web", "api"] : {
      Effect    = "Allow", Action = "ecs:UpdateService",
      Resource  = "arn:aws:ecs:${var.aws_region}:${var.account_id}:service/${local.prefix}/${local.prefix}-${tier}",
      Condition = { ArnLike = { "ecs:task-definition" = "arn:aws:ecs:${var.aws_region}:${var.account_id}:task-definition/${local.prefix}-${tier}:*" } }
  }]) })
}
