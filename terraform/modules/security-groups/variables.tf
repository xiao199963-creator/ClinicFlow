variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "web_port" {
  type    = number
  default = 8080
}

variable "internal_alb_port" {
  type    = number
  default = 80
}

variable "api_port" {
  type    = number
  default = 5000
}
