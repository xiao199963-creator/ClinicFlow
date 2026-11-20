locals { name = "clinicflow-audit" }
resource "aws_kms_key" "audit" {
  description             = "ClinicFlow account audit encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  lifecycle { prevent_destroy = true }
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "EnableAccountIAM", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }, Action = "kms:*", Resource = "*" },
    { Sid = "CloudTrail", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = ["kms:GenerateDataKey*", "kms:DescribeKey", "kms:Decrypt"], Resource = "*", Condition = { StringEquals = { "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${local.name}" } } }
  ] })
}
resource "aws_kms_alias" "audit" {
  name          = "alias/clinicflow/audit"
  target_key_id = aws_kms_key.audit.key_id
}
resource "aws_s3_bucket" "audit" {
  bucket        = "clinicflow-${var.account_id}-${var.aws_region}-audit"
  force_destroy = false
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    id     = "audit-retention"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
  depends_on = [aws_s3_bucket_versioning.audit]
}
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } },
    { Sid = "CloudTrailACL", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:GetBucketAcl", Resource = aws_s3_bucket.audit.arn, Condition = { StringEquals = { "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${local.name}" } } },
    { Sid = "CloudTrailWrite", Effect = "Allow", Principal = { Service = "cloudtrail.amazonaws.com" }, Action = "s3:PutObject", Resource = "${aws_s3_bucket.audit.arn}/AWSLogs/${var.account_id}/*", Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control", "aws:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${local.name}" } } }
  ] })
  depends_on = [aws_s3_bucket_public_access_block.audit]
}
resource "aws_cloudtrail" "main" {
  name                          = local.name
  s3_bucket_name                = aws_s3_bucket.audit.id
  kms_key_id                    = aws_kms_key.audit.arn
  enable_logging                = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true
  depends_on                    = [aws_s3_bucket_policy.audit, aws_s3_bucket_server_side_encryption_configuration.audit]
}
