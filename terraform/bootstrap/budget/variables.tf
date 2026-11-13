variable "monthly_budget" {
  description = "The monthly budget amount for the project"
  type = number
  default = 100
}

variable "email_address" {
  description = "The email address to receive budget notifications"
  type = string
  default = "xiao199963@gmail.com"
}