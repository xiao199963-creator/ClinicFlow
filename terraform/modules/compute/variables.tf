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
}
variable "api_port" {
  type    = number
  default = 5000
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
