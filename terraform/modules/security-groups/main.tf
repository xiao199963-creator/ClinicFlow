resource "aws_security_group" "public_alb" {
  name_prefix = "${var.environment}-public-alb-"
  description = "Security group for the public ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-public-alb-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_alb_https" {
  security_group_id = aws_security_group.public_alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "Allow HTTPS from the internet"
}

locals {
  tier_groups = toset(["web", "internal_alb", "api", "database"])
  ids = merge({ public_alb = aws_security_group.public_alb.id }, {
    for name, group in aws_security_group.tier : name => group.id
  })
  connections = {
    public_to_web   = { source = "public_alb", destination = "web", port = var.web_port }
    web_to_internal = { source = "web", destination = "internal_alb", port = var.internal_alb_port }
    internal_to_api = { source = "internal_alb", destination = "api", port = var.api_port }
    api_to_database = { source = "api", destination = "database", port = 3306 }
  }
}

resource "aws_security_group" "tier" {
  for_each    = local.tier_groups
  name_prefix = "clinicflow-${var.environment}-${replace(each.key, "_", "-")}-"
  description = "ClinicFlow ${each.key} tier"
  vpc_id      = var.vpc_id

  tags = { Name = "clinicflow-${var.environment}-${each.key}" }
}

# Both sides of each new connection are explicit; replies are statefully allowed.
resource "aws_vpc_security_group_ingress_rule" "tier" {
  for_each                     = local.connections
  security_group_id            = local.ids[each.value.destination]
  referenced_security_group_id = local.ids[each.value.source]
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.key
}

resource "aws_vpc_security_group_egress_rule" "tier" {
  for_each                     = local.connections
  security_group_id            = local.ids[each.value.source]
  referenced_security_group_id = local.ids[each.value.destination]
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  description                  = each.key
}

# Image pulls, log delivery and AWS APIs use NAT HTTPS. This is not tier-to-tier access.
resource "aws_vpc_security_group_egress_rule" "aws_https" {
  for_each          = toset(["web", "api"])
  security_group_id = local.ids[each.key]
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AWS APIs through NAT"
}
