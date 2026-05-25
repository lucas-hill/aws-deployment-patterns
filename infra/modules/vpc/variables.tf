variable "name_prefix" {
  description = "Prefix used to name VPC resources (e.g. 'lucas-dev', 'lucas-prod')"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a valid /16-/28 range."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = "Map of AZ name to CIDR block for public subnets"
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of AZ name to CIDR block for private subnets"
  type        = map(string)
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
