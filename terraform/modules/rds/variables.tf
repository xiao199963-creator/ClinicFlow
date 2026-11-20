variable "environment" {
  type        = string
  description = "Environment name"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Isolated data subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "Two AZs"
}

variable "security_group_id" {
  type        = string
  description = "Database SG"
}

variable "kms_key_arn" {
  type        = string
  description = "Database and managed secret KMS key"
}

variable "log_kms_key_arn" {
  type        = string
  description = "CloudWatch KMS key"
}

variable "instance_count" {
  type        = number
  description = "One writer, optionally a reader"
  default     = 1
}

variable "instance_class" {
  type        = string
  description = "Legacy provisioned default; set db.serverless with scaling after migration approval"
  default     = "db.t4g.medium"
}

variable "engine_version" {
  type        = string
  description = "Pin a region-supported Aurora MySQL 8 version before production; null selects AWS default"
  default     = null
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion"
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Database log retention"
  default     = 30
}

variable "backup_retention_days" { type = number }
variable "skip_final_snapshot" { type = bool }
variable "final_snapshot_identifier" { type = string }
variable "delete_automated_backups" { type = bool }
variable "serverlessv2_scaling" {
  type    = object({ min_capacity = number, max_capacity = number, seconds_until_auto_pause = optional(number, 300) })
  default = null
  validation {
    condition     = var.serverlessv2_scaling == null ? true : (var.serverlessv2_scaling.min_capacity >= 0 && var.serverlessv2_scaling.max_capacity >= 1 && var.serverlessv2_scaling.min_capacity <= var.serverlessv2_scaling.max_capacity && var.serverlessv2_scaling.seconds_until_auto_pause >= 300 && var.serverlessv2_scaling.seconds_until_auto_pause <= 86400)
    error_message = "Use an ordered capacity range and an auto-pause interval of 300–86400 seconds."
  }
}
