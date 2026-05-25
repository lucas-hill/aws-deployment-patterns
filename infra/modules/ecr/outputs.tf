output "repository_url" {
  description = "Full URL of the repository (use as the image registry in Docker)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository (use in IAM policies)"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the repository"
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "AWS account ID where the registry lives (your account)"
  value       = aws_ecr_repository.this.registry_id
}
