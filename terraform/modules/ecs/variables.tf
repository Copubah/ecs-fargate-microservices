variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "alb_target_group_a_arn" {
  description = "ALB target group ARN for Service A"
  type        = string
}

variable "alb_target_group_b_arn" {
  description = "ALB target group ARN for Service B"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "service_a_image" {
  description = "Docker image for Service A"
  type        = string
}

variable "service_b_image" {
  description = "Docker image for Service B"
  type        = string
}

variable "service_a_cpu" {
  description = "CPU units for Service A"
  type        = number
}

variable "service_a_memory" {
  description = "Memory for Service A"
  type        = number
}

variable "service_b_cpu" {
  description = "CPU units for Service B"
  type        = number
}

variable "service_b_memory" {
  description = "Memory for Service B"
  type        = number
}
