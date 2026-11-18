variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}
variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Set a target AWS account ID."
  }
}
variable "github_repository" {
  type    = string
  default = "xiao199963-creator/ClinicFlow"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use owner/repo without URL or wildcards."
  }
}
variable "budget_name" {
  type    = string
  default = "clinicflow-budget"
}
