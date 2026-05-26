output "alb_dns_name" {
  description = "DNS name of the load balancer — use this to reach the app"
  value       = aws_lb.app.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group (for debugging/scaling commands)"
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "ARN of the target group (useful for checking target health)"
  value       = aws_lb_target_group.app.arn
}
