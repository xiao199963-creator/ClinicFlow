output "public_dns_name" { value = aws_lb.main["web"].dns_name }
output "public_zone_id" { value = aws_lb.main["web"].zone_id }
output "internal_dns_name" { value = aws_lb.main["api"].dns_name }
output "target_group_arns" { value = { for tier, group in aws_lb_target_group.main : tier => group.arn } }
output "target_group_arn_suffixes" { value = { for tier, group in aws_lb_target_group.main : tier => group.arn_suffix } }
output "load_balancer_arn_suffixes" { value = { for tier, lb in aws_lb.main : tier => lb.arn_suffix } }
