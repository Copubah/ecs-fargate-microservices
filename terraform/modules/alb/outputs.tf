output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch"
  value       = aws_lb.main.arn_suffix
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "target_group_a_arn" {
  description = "Target group A ARN"
  value       = aws_lb_target_group.service_a.arn
}

output "target_group_b_arn" {
  description = "Target group B ARN"
  value       = aws_lb_target_group.service_b.arn
}

output "target_group_a_arn_suffix" {
  description = "Target group A ARN suffix"
  value       = aws_lb_target_group.service_a.arn_suffix
}

output "target_group_b_arn_suffix" {
  description = "Target group B ARN suffix"
  value       = aws_lb_target_group.service_b.arn_suffix
}
