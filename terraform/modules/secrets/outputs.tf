output "data_kms_key_arn" { value = aws_kms_key.data.arn }
output "log_kms_key_arn" { value = aws_kms_key.logs.arn }
