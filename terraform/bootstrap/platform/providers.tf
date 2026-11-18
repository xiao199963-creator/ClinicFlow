provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { Project = "clinicflow", Environment = "shared", ManagedBy = "Terraform", Owner = "platform" }
  }
}
