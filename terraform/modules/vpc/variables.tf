variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "The environment for the VPC (e.g., dev, prod)"
  type        = string
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-2a", "ap-southeast-2b"]
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Provide exactly two distinct availability zones."
  }
}

variable "nat_gateway_count" {
  type = number
  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count must be 1 or 2."
  }
}
variable "subnet_offsets" {
  type = object({ public = list(number), web = list(number), api = list(number), data = list(number) })
  validation {
    condition     = alltrue([for offsets in values(var.subnet_offsets) : length(offsets) == 2]) && length(distinct(flatten(values(var.subnet_offsets)))) == 8 && alltrue([for offset in flatten(values(var.subnet_offsets)) : offset >= 0 && offset <= 255 && floor(offset) == offset])
    error_message = "Provide eight distinct /24 subnet offsets, two per tier, in 0..255."
  }
}
