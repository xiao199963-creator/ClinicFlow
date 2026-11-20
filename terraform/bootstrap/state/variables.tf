
variable "shared_kms_key_arn" {
  type        = string
  default     = null
  description = "Existing ECR shared key ARN from bootstrap/platform. Null preserves legacy SSE-S3 until state IAM/migration approval."
}
