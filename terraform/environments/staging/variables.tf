variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}
variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}
variable "aws_account_id" {
  type        = string
  description = "Guard against deploying into the wrong account."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Provide your target 12-digit account ID."
  }
}
variable "owner" {
  type    = string
  default = "platform"
}
variable "vpc_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "Provide an IPv4 /16 network for eight /24 subnets."
  }
}
variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-2a", "ap-southeast-2b"]
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 && alltrue([for az in var.availability_zones : startswith(az, var.aws_region)])
    error_message = "Two distinct AZs in the selected region are required."
  }
}
variable "high_availability" {
  type    = bool
  default = false
  validation {
    condition     = var.environment != "prod" || var.high_availability
    error_message = "Production requires an independent NAT in each AZ."
  }
}
variable "budget_name" {
  type        = string
  default     = "clinicflow-budget"
  description = "Must already exist in this account before infrastructure is created."
}
variable "certificate_arn" {
  type        = string
  description = "An ISSUED ACM certificate matching the application hostname in this region."
  validation {
    condition     = can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn)) && startswith(var.certificate_arn, "arn:aws:acm:${var.aws_region}:${var.aws_account_id}:")
    error_message = "Provide a real ACM certificate ARN in the target region and account."
  }
}
variable "domain_name" {
  type        = string
  default     = null
  description = "Optional Route53 record; the certificate must cover this hostname."
  validation {
    condition     = (var.domain_name == null) == (var.hosted_zone_id == null)
    error_message = "Set both domain_name and hosted_zone_id, or leave both null."
  }
}
variable "hosted_zone_id" {
  type    = string
  default = null
}
variable "github_repository" {
  type    = string
  default = "xiao199963-creator/ClinicFlow"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use owner/repository without URL or wildcard."
  }
}
variable "github_oidc_provider_arn" {
  type = string
  validation {
    condition     = var.github_oidc_provider_arn == "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
    error_message = "Use the GitHub OIDC provider created once by bootstrap/platform in this account."
  }
}
variable "image_repository_urls" {
  type        = map(string)
  description = "Shared bootstrap/platform ECR URLs, reused in all environments."
  validation {
    condition     = toset(keys(var.image_repository_urls)) == toset(["web", "api"]) && alltrue([for url in values(var.image_repository_urls) : can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/.+$", url)) && startswith(url, "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/")])
    error_message = "Provide web and api ECR repository URLs from the shared platform in this account and region."
  }
}
variable "image_digests" {
  type        = map(string)
  description = "Promote the same tested immutable image digests between environments."
  validation {
    condition     = toset(keys(var.image_digests)) == toset(["web", "api"]) && alltrue([for digest in values(var.image_digests) : can(regex("^sha256:[0-9a-f]{64}$", digest))])
    error_message = "Provide web and api sha256 digests with 64 lowercase hex characters; mutable tags are forbidden."
  }
}
variable "desired_count" {
  type    = number
  default = 1
  validation {
    condition     = var.desired_count >= 1 && floor(var.desired_count) == var.desired_count && (var.environment != "prod" || var.desired_count >= 2)
    error_message = "Use at least one task per service; production requires at least two."
  }
}
variable "database_instance_count" {
  type    = number
  default = 1
  validation {
    condition     = contains([1, 2], var.database_instance_count) && (var.environment != "prod" || var.database_instance_count == 2)
    error_message = "Use one or two Aurora instances; production requires two."
  }
}
variable "database_instance_class" {
  type    = string
  default = "db.t4g.medium"
}
variable "database_engine_version" {
  type        = string
  default     = null
  description = "Set an Aurora MySQL 8 version available in the target region; null uses AWS default."
  validation {
    condition     = var.database_engine_version == null ? true : startswith(var.database_engine_version, "8.0.mysql_aurora.3.")
    error_message = "Use Aurora MySQL 3 (MySQL 8) to match the parameter group."
  }
}
variable "deletion_protection" {
  type    = bool
  default = false
  validation {
    condition     = var.environment != "prod" || var.deletion_protection
    error_message = "Production ALBs and Aurora must enable deletion protection."
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
variable "task_cpu" {
  type    = number
  default = 256
}
variable "task_memory" {
  type    = number
  default = 512
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu) && contains(lookup({ "256" = [512, 1024, 2048], "512" = [1024, 2048, 3072, 4096], "1024" = range(2048, 8193, 1024), "2048" = range(4096, 16385, 1024), "4096" = range(8192, 30721, 1024) }, tostring(var.task_cpu), []), var.task_memory)
    error_message = "Choose a supported Fargate CPU/memory pair (MiB)."
  }
}
variable "log_retention_days" {
  type    = number
  default = 30
  validation {
    condition     = contains([7, 14, 30, 60, 90, 180, 365], var.log_retention_days)
    error_message = "Use a supported log retention period."
  }
}
variable "alarm_email" {
  type = string
  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.alarm_email))
    error_message = "Provide an email address and confirm its SNS subscription after deployment."
  }
}
