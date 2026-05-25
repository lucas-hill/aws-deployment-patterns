variable "aws_region" {
  description = "AWS region for the state backend resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile to authenticate with"
  type        = string
  default     = "lucas-sso"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that will hold Terraform state files. Must be globally unique across all AWS accounts."
  type        = string
  default     = "lucas-tf-state-281639842765"
}

variable "state_lock_table_name" {
  description = "Name of the DynamoDB table used for state locking"
  type        = string
  default     = "lucas-tf-state-lock"
}
