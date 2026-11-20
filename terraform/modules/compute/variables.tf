variable "environment" { type = string }
variable "aws_region" { type = string }
variable "subnet_ids" { type = map(list(string)) }
variable "security_group_ids" { type = map(string) }
variable "target_group_arns" { type = map(string) }
variable "execution_role_arns" { type = map(string) }
variable "task_role_arns" { type = map(string) }
variable "images" { type = map(string) }
variable "internal_alb_dns_name" { type = string }
variable "database_endpoint" { type = string }
variable "log_kms_key_arn" { type = string }
variable "desired_count" {
  type = number
  validation {
    condition     = var.desired_count >= 1 && floor(var.desired_count) == var.desired_count
    error_message = "At least one task per service is required."
  }
}
variable "web_port" {
  type    = number
  default = 8080
  validation {
    condition     = floor(var.web_port) == var.web_port && var.web_port >= 1024 && var.web_port <= 65535
    error_message = "Choose an unprivileged TCP port from 1024 to 65535 for the web container."
  }
}
variable "api_port" {
  type    = number
  default = 5000
  validation {
    condition     = floor(var.api_port) == var.api_port && var.api_port >= 1024 && var.api_port <= 65535
    error_message = "Choose an unprivileged TCP port from 1024 to 65535 for the api container."
  }
}
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "log_retention_days" {
  type    = number
  default = 30
}

variable "container_insights_enabled" {
  type    = bool
  default = false
}
variable "minimum_task_count" {
  type    = number
  default = 1
}

variable "master_secret_arn" { type = string }
