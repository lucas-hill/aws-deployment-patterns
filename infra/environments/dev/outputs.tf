#NOTE: VPC outputs
output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the dev VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

#NOTE: ECR outputs
output "ecr_repository_url" {
  description = "ECR repository URL for the Go API image"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN (used by EC2 IAM role)"
  value       = module.ecr.repository_arn
}

#NOTE: EC2 and ALB outputs
output "alb_dns_name" {
  description = "Load balancer DNS — curl this to hit the API"
  value       = module.compute.alb_dns_name
}

output "asg_name" {
  description = "Auto Scaling Group name for the app"
  value       = module.compute.asg_name
}

output "target_group_arn" {
  description = "Target group ARN — useful for checking instance health"
  value       = module.compute.target_group_arn
}
