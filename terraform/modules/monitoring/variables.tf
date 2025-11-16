variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_a_name" {
  description = "ECS Service A name"
  type        = string
}

variable "ecs_service_b_name" {
  description = "ECS Service B name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
}

variable "target_group_a_arn_suffix" {
  description = "Target Group A ARN suffix"
  type        = string
}

variable "target_group_b_arn_suffix" {
  description = "Target Group B ARN suffix"
  type        = string
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}
