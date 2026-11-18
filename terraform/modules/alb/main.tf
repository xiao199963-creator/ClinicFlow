locals {
  tiers = {
    web = { internal = false, subnets = var.public_subnet_ids, sg = var.security_group_ids["public_alb"], port = var.web_port }
    api = { internal = true, subnets = var.private_subnet_ids, sg = var.security_group_ids["internal_alb"], port = var.api_port }
  }
}

# ALB access log delivery supports SSE-S3, not a customer KMS key.
resource "aws_s3_bucket" "access_logs" {
  bucket        = "clinicflow-${var.account_id}-${var.environment}-${var.aws_region}-alb"
  force_destroy = var.environment != "prod"
}
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "log-retention"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = var.environment == "prod" ? 365 : 30 }
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
  depends_on = [aws_s3_bucket_versioning.access_logs]
}
resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } },
    { Sid = "ALBLogDelivery", Effect = "Allow", Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }, Action = "s3:PutObject", Resource = [for tier in keys(local.tiers) : "${aws_s3_bucket.access_logs.arn}/${tier}/AWSLogs/${var.account_id}/*"] }
  ] })
  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}

resource "aws_lb" "main" {
  for_each                   = local.tiers
  name                       = "clinicflow-${var.environment}-${each.key}"
  internal                   = each.value.internal
  load_balancer_type         = "application"
  security_groups            = [each.value.sg]
  subnets                    = each.value.subnets
  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
  access_logs {
    bucket  = aws_s3_bucket.access_logs.id
    prefix  = each.key
    enabled = true
  }
  depends_on = [aws_s3_bucket_policy.access_logs, aws_s3_bucket_server_side_encryption_configuration.access_logs]
}

resource "aws_lb_target_group" "main" {
  for_each             = local.tiers
  name_prefix          = "${each.key}-"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  protocol             = "HTTP"
  port                 = each.value.port
  deregistration_delay = 30
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_lb_listener" "public_https" {
  load_balancer_arn = aws_lb.main["web"].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["web"].arn
  }
}
resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.main["api"].arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["api"].arn
  }
}
