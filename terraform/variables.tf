variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecs-microservices"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "service_a_cpu" {
  description = "CPU units for Service A (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "service_a_memory" {
  description = "Memory for Service A in MB"
  type        = number
  default     = 512
}

variable "service_b_cpu" {
  description = "CPU units for Service B"
  type        = number
  default     = 256
}

variable "service_b_memory" {
  description = "Memory for Service B in MB"
  type        = number
  default     = 512
}

variable "enable_waf" {
  description = "Enable AWS WAF on ALB"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository for OIDC (format: owner/repo)"
  type        = string
  default     = "your-org/your-repo"
}
