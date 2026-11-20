variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "route_table_ids" { type = list(string) }
variable "subnet_ids" { type = list(string) }
variable "enable_interface_endpoints" { type = bool }
variable "endpoint_source_security_group_ids" { type = map(string) }
