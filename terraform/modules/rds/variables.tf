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
  description = "Aurora instances: production requires two"
  default     = 1
}

variable "instance_class" {
  type        = string
  description = "Aurora instance type"
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
