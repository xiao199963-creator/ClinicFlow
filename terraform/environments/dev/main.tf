data "aws_caller_identity" "current" {}
data "aws_budgets_budget" "prerequisite" { name = var.budget_name }

locals {
  repository_arns = { for tier, url in var.image_repository_urls : tier => "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${join("/", slice(split("/", url), 1, length(split("/", url))))}" }
  images          = { for tier, url in var.image_repository_urls : tier => "${url}@${var.image_digests[tier]}" }
}

module "vpc" {
  source             = "../../modules/vpc"
  vpc_cidr           = var.vpc_cidr
  environment        = var.environment
  availability_zones = var.availability_zones
  high_availability  = var.high_availability
  depends_on         = [data.aws_budgets_budget.prerequisite]
}
module "security_groups" {
  source      = "../../modules/security-groups"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
  web_port    = var.web_port
  api_port    = var.api_port
}
module "secrets" {
  source      = "../../modules/secrets"
  environment = var.environment
  aws_region  = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
  depends_on  = [data.aws_budgets_budget.prerequisite]
}
module "rds" {
  source              = "../../modules/rds"
  environment         = var.environment
  subnet_ids          = values(module.vpc.private_data_subnet_ids)
  availability_zones  = var.availability_zones
  security_group_id   = module.security_groups.ids["database"]
  kms_key_arn         = module.secrets.data_kms_key_arn
  log_kms_key_arn     = module.secrets.log_kms_key_arn
  instance_count      = var.database_instance_count
  instance_class      = var.database_instance_class
  engine_version      = var.database_engine_version
  deletion_protection = var.deletion_protection
  log_retention_days  = var.log_retention_days
}
module "iam" {
  source                 = "../../modules/iam"
  environment            = var.environment
  aws_region             = var.aws_region
  account_id             = data.aws_caller_identity.current.account_id
  github_repository      = var.github_repository
  oidc_provider_arn      = var.github_oidc_provider_arn
  repository_arns        = local.repository_arns
  db_cluster_resource_id = module.rds.cluster_resource_id
  master_secret_arn      = module.rds.master_secret_arn
  data_kms_key_arn       = module.secrets.data_kms_key_arn
}
module "alb" {
  source              = "../../modules/alb"
  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  aws_region          = var.aws_region
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = values(module.vpc.public_subnet_ids)
  private_subnet_ids  = values(module.vpc.private_api_subnet_ids)
  security_group_ids  = module.security_groups.ids
  certificate_arn     = var.certificate_arn
  deletion_protection = var.deletion_protection
  web_port            = var.web_port
  api_port            = var.api_port
}
module "compute" {
  source                = "../../modules/compute"
  environment           = var.environment
  aws_region            = var.aws_region
  subnet_ids            = { web = values(module.vpc.private_web_subnet_ids), api = values(module.vpc.private_api_subnet_ids) }
  security_group_ids    = module.security_groups.ids
  target_group_arns     = module.alb.target_group_arns
  execution_role_arns   = module.iam.execution_role_arns
  task_role_arns        = module.iam.task_role_arns
  images                = local.images
  internal_alb_dns_name = module.alb.internal_dns_name
  database_endpoint     = module.rds.endpoint
  log_kms_key_arn       = module.secrets.log_kms_key_arn
  desired_count         = var.desired_count
  web_port              = var.web_port
  api_port              = var.api_port
  cpu                   = var.task_cpu
  memory                = var.task_memory
  log_retention_days    = var.log_retention_days
  depends_on            = [module.alb, module.iam, module.vpc, module.rds]
}
module "monitoring" {
  source                     = "../../modules/monitoring"
  environment                = var.environment
  aws_region                 = var.aws_region
  account_id                 = data.aws_caller_identity.current.account_id
  vpc_id                     = module.vpc.vpc_id
  cluster_name               = module.compute.cluster_name
  service_names              = module.compute.service_names
  desired_count              = var.desired_count
  database_cluster_id        = module.rds.cluster_id
  load_balancer_arn_suffixes = module.alb.load_balancer_arn_suffixes
  target_group_arn_suffixes  = module.alb.target_group_arn_suffixes
  data_kms_key_arn           = module.secrets.data_kms_key_arn
  log_kms_key_arn            = module.secrets.log_kms_key_arn
  alarm_email                = var.alarm_email
  log_retention_days         = var.log_retention_days
}
resource "aws_route53_record" "application" {
  count   = var.domain_name == null ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = module.alb.public_dns_name
    zone_id                = module.alb.public_zone_id
    evaluate_target_health = true
  }
}
