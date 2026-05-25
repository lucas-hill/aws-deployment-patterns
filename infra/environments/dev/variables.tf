variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile name"
  type        = string
  default     = "lucas-sso"
}

variable "name_prefix" {
  description = "Prefix for resource names in this environment"
  type        = string
  default     = "lucas-dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, keyed by AZ"
  type        = map(string)
  default = {
    "us-west-2a" = "10.0.1.0/24"
    "us-west-2b" = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, keyed by AZ"
  type        = map(string)
  default = {
    "us-west-2a" = "10.0.11.0/24"
    "us-west-2b" = "10.0.12.0/24"
  }
}
