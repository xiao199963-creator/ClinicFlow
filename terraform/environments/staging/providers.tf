provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Project     = "clinicflow"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCentre  = var.cost_centre
    }
  }
}
