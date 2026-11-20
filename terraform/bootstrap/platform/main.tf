data "aws_caller_identity" "current" {}
data "aws_budgets_budget" "prerequisite" { name = var.budget_name }

module "ecr" {
  source           = "../../modules/ecr"
  repository_names = var.repository_names
  depends_on       = [data.aws_budgets_budget.prerequisite]
}
module "audit" {
  source     = "../../modules/audit"
  account_id = data.aws_caller_identity.current.account_id
  aws_region = var.aws_region
  depends_on = [data.aws_budgets_budget.prerequisite]
}
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  depends_on     = [data.aws_budgets_budget.prerequisite]
}
resource "aws_iam_role" "github_build" {
  name = "clinicflow-github-build"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow"
    Action    = "sts:AssumeRoleWithWebIdentity"
    Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
    } }
  }] })
}
resource "aws_iam_role_policy" "github_build" {
  role = aws_iam_role.github_build.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:DescribeImages", "ecr:DescribeImageScanFindings"], Resource = values(module.ecr.repository_arns) }
  ] })
}
