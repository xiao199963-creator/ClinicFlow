variable "environment" { type = string }
variable "account_id" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = map(string) }
variable "certificate_arn" { type = string }
variable "deletion_protection" { type = bool }
variable "web_port" { type = number }
variable "api_port" { type = number }

variable "access_logs_force_destroy" { type = bool }
variable "access_logs_retention_days" { type = number }

variable "web_health_check_path" { type = string }
