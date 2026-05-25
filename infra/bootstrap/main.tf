# ============================================================
# S3 bucket that holds Terraform state files
# ============================================================

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Safety net: refuse to destroy this bucket if it contains objects.
  # State files live here — losing them is catastrophic.
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning. If a state file gets corrupted or a teammate
# applies a bad change, you can roll back to a previous version.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest. State files contain secrets in plaintext
# (database passwords, API keys baked into resource configs).
# AES256 with AWS-managed keys is the minimum.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access. State files should never be reachable
# from the internet under any circumstances.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# DynamoDB table for state locking
# ============================================================

resource "aws_dynamodb_table" "tf_state_lock" {
  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
