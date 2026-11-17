resource "aws_kms_key" "ecr" {
  description             = "Shared ClinicFlow ECR encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.name_prefix}/ecr"
  target_key_id = aws_kms_key.ecr.key_id
}
resource "aws_ecr_repository" "main" {
  for_each             = toset(["web", "api"])
  name                 = "${var.name_prefix}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
}
# Only untagged images are expired. Tagged rollback releases remain available.
resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = aws_ecr_repository.main
  repository = each.value.name
  policy = jsonencode({ rules = [{
    rulePriority = 1
    description  = "Expire untagged images after 7 days"
    selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
    action       = { type = "expire" }
  }] })
}
