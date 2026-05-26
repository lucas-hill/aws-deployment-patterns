# ============================================================
# ALB security group — accepts HTTP from internet, sends to EC2
# ============================================================
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow HTTP from the internet to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (to EC2 targets)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

# ============================================================
# App security group — accepts traffic on app port from ALB only
# ============================================================
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Allow traffic from ALB on app port"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (for VPC endpoint access)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-sg"
  })
}

# ============================================================
# VPC endpoint security group — accepts HTTPS from inside VPC
# ============================================================
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "Allow HTTPS from VPC to interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from inside VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-sg"
  })
}

#NOTE: IAM for the EC2 Instance
# ============================================================
# Trust policy — defines who can assume this role
# building out the trust policy to apply to a role
# ============================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ============================================================
# IAM role for the EC2 instance
# Assigning the trust policy in the role
# ============================================================
resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags
}

# ============================================================
# Permissions policy — allow ECR pull, scoped to our repo
# Whoever is wearing this role can perfrom these actions
# ============================================================
data "aws_iam_policy_document" "ecr_pull" {
  #Get a temporary docker login token
  statement {
    sid     = "ECRAuthToken"
    actions = ["ecr:GetAuthorizationToken"]
    # This specific action doesn't support resource scoping in AWS
    resources = ["*"]
  }

  #Allows you to perform the actual image pull operations
  statement {
    sid = "ECRPullFromOurRepo"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "${var.name_prefix}-ecr-pull"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

# ============================================================
# Attach AWS-managed SSM policy — enables Session Manager
# This allows you to open connections without SSH
# ============================================================
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================
# Instance profile — what actually attaches to the EC2
# Wrapper around the role so you can attach to an EC2 instance
# ============================================================
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

#NOTE: VPC Endpoints
# ============================================================
# S3 gateway endpoint — free; required for ECR image layer pulls
# Routes S3 traffic via the VPC's route table, not the internet
# ============================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-west-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [var.private_route_table_id]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-endpoint"
  })
}

# ============================================================
# ECR API interface endpoint — for ECR auth and manifest API calls
# ============================================================
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecr-api-endpoint"
  })
}

# ============================================================
# ECR DKR interface endpoint — for Docker image layer transfers
# ============================================================
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-west-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecr-dkr-endpoint"
  })
}

#NOTE: EC2 and ALB
# ============================================================
# Latest Amazon Linux 2023 AMI for x86_64
# ============================================================
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ============================================================
# user_data — runs once on first boot
# ============================================================
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -e

    # Install Docker
    dnf install -y docker
    systemctl enable --now docker

    # Authenticate to ECR using the instance profile credentials
    aws ecr get-login-password --region us-west-2 \
      | docker login --username AWS --password-stdin ${split("/", var.ecr_repository_url)[0]}

    # Pull and run the container
    docker pull ${var.ecr_repository_url}:${var.image_tag}
    docker run -d \
      --name go-api \
      --restart always \
      -p ${var.app_port}:${var.app_port} \
      ${var.ecr_repository_url}:${var.image_tag}
  EOT
}

# ============================================================
# Launch template — describes what each ASG-managed EC2 looks like
# Replaces the single aws_instance from the non-HA version.
# Acts as the "image" for instances the ASG creates.
# ============================================================
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  # user_data on launch templates must be base64-encoded.
  # The aws_instance resource did this implicitly; launch templates don't.
  user_data = base64encode(local.user_data)

  # Tags applied to instances the ASG launches.
  # Launch template's own tags don't propagate — you set them per resource_type.
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-app-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-launch-template"
  })
}

# ============================================================
# Auto Scaling Group — keeps N instances running across AZs
# Replaces the single aws_instance + aws_lb_target_group_attachment.
# Distributes instances across the private subnets we pass in.
# ============================================================
resource "aws_autoscaling_group" "app" {
  name = "${var.name_prefix}-asg"

  # Capacity settings. min/desired=2 means one instance per AZ at all times.
  # max=4 lets you scale up if you ever add a scaling policy.
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  # Place instances across both private subnets (and therefore both AZs).
  vpc_zone_identifier = var.private_subnet_ids

  # Register instances directly with the target group.
  # Replaces aws_lb_target_group_attachment entirely.
  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Use the ALB's health check, not just EC2 status checks.
  # Without this, the ASG only replaces an instance if EC2 itself dies —
  # not if the app crashes. ELB health checks include the app responding.
  health_check_type = "ELB"

  # Wait this long after launching before health-checking.
  # Gives user_data time to install Docker, pull, and start the container.
  health_check_grace_period = 180

  # Ensure VPC endpoints exist before ASG launches instances; otherwise
  # user_data fails trying to reach ECR.
  depends_on = [
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.s3,
  ]

  # ASG tags use a different syntax than other resources — list of tag blocks
  # instead of a map. Each tag has a propagate_at_launch flag.
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg"
    propagate_at_launch = false
  }
}

# ============================================================
# Application Load Balancer
# ============================================================
resource "aws_lb" "app" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# ============================================================
# Target group — defines health checks and what gets routed to
# Note: no aws_lb_target_group_attachment anymore — the ASG handles
# registration/deregistration directly.
# ============================================================
resource "aws_lb_target_group" "app" {
  name     = "${var.name_prefix}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tg"
  })
}

# ============================================================
# Listener — terminates port 80 on ALB and forwards to target group
# ============================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

