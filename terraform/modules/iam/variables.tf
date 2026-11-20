variable "environment" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "github_repository" { type = string }
variable "oidc_provider_arn" { type = string }
variable "repository_arns" { type = map(string) }
variable "master_secret_arn" { type = string }
variable "data_kms_key_arn" { type = string }

variable "bootstrap_operator_role_arn" { type = string }
variable "log_kms_key_arn" { type = string }
