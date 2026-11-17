output "trail_arn" { value = aws_cloudtrail.main.arn }
output "bucket_name" { value = aws_s3_bucket.audit.id }
