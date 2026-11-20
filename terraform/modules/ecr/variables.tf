variable "name_prefix" {
  type        = string
  description = "Shared image repository prefix"
  default     = "clinicflow"
}

variable "repository_names" {
  type    = map(string)
  default = { web = "clinicflow/web", api = "clinicflow/api" }
  validation {
    condition     = toset(keys(var.repository_names)) == toset(["web", "api"])
    error_message = "Provide web and api repository names."
  }
}
