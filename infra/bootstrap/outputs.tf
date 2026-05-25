output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state"
  value       = aws_s3_bucket.tf_state.id
}

output "state_lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.tf_state_lock.id
}

output "region" {
  description = "Region where state backend resources live"
  value       = var.aws_region
}
