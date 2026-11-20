locals {
  prefix = "clinicflow-${var.environment}"
  ports  = { web = var.web_port, api = var.api_port }
  environment = {
    web = { APP_ENV = var.environment, API_UPSTREAM = "http://${var.internal_alb_dns_name}" }
    api = {
      APP_ENV      = var.environment
      AWS_REGION   = var.aws_region
      DB_HOST      = var.database_endpoint
      DB_PORT      = "3306"
      DB_NAME      = "clinicflow"
      DB_USER      = "clinicflow_app"
      DB_AUTH_MODE = "iam"
      DB_SSL_CA    = "/app/certs/global-bundle.pem"
    }
  }
}
resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.ports
  name              = "/clinicflow/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
}
resource "aws_ecs_cluster" "main" {
  name = local.prefix
  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled"
  }
}
resource "aws_ecs_task_definition" "main" {
  for_each                 = local.ports
  family                   = "${local.prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arns[each.key]
  task_role_arn            = var.task_role_arns[each.key]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  volume { name = "tmp" }
  container_definitions = jsonencode([{
    name                   = each.key
    image                  = var.images[each.key]
    essential              = true
    user                   = "10001:10001"
    readonlyRootFilesystem = true
    privileged             = false
    linuxParameters        = { capabilities = { drop = ["ALL"] } }
    portMappings           = [{ containerPort = each.value, hostPort = each.value, protocol = "tcp" }]
    mountPoints            = [{ sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }]
    environment            = [for name, value in merge(local.environment[each.key], { PORT = tostring(each.value) }) : { name = name, value = value }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service[each.key].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    stopTimeout = 60
  }])
}
resource "aws_ecs_service" "main" {
  for_each                           = local.ports
  name                               = "${local.prefix}-${each.key}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main[each.key].arn
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  availability_zone_rebalancing      = "ENABLED"
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  enable_execute_command             = false
  health_check_grace_period_seconds  = 120
  wait_for_steady_state              = true
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = var.subnet_ids[each.key]
    security_groups  = [var.security_group_ids[each.key]]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    container_port   = each.value
  }
  timeouts {
    create = "15m"
    update = "15m"
  }
  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.desired_count >= 2
      error_message = "Production requires at least two tasks per service."
    }
  }
}
