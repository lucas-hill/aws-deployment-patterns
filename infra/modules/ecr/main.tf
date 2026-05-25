resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the ${var.lifecycle_policy_keep_count} most recent untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = var.lifecycle_policy_keep_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
