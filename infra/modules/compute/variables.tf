variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy into"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block (used by VPC endpoint security group)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EC2 and VPC endpoints"
  type        = list(string)
}

variable "private_route_table_id" {
  description = "Route table ID for the private subnets (used by S3 gateway endpoint)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN — used to scope EC2 IAM policy"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL — used in EC2 user_data to pull the image"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Port the Go API listens on inside the container"
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
