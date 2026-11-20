# S3 gateway routes also cover isolated Data subnets without adding an internet route.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  tags              = { Name = "clinicflow-${var.environment}-s3-endpoint" }
}
resource "aws_security_group" "endpoints" {
  count       = var.enable_interface_endpoints ? 1 : 0
  name_prefix = "clinicflow-${var.environment}-endpoints-"
  vpc_id      = var.vpc_id
  description = "Private AWS API endpoints; HTTPS from task tiers only"
}
resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  for_each                     = var.enable_interface_endpoints ? var.endpoint_source_security_group_ids : {}
  security_group_id            = aws_security_group.endpoints[0].id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = var.enable_interface_endpoints ? toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager"]) : toset([])
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags                = { Name = "clinicflow-${var.environment}-${each.key}-endpoint" }
}
