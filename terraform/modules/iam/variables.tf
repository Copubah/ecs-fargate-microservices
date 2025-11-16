variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs"
  type        = list(string)
}

variable "github_repo" {
  description = "GitHub repository (owner/repo)"
  type        = string
}
