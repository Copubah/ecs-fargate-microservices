terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
  environment  = var.environment
  repositories = ["service-a", "service-b"]
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
  ecr_repository_arns = module.ecr.repository_arns
  github_repo = var.github_repo
}

# ALB Module
module "alb" {
  source = "./modules/alb"
  
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  
  enable_waf = var.enable_waf
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  
  alb_target_group_a_arn = module.alb.target_group_a_arn
  alb_target_group_b_arn = module.alb.target_group_b_arn
  alb_security_group_id  = module.alb.alb_security_group_id
  
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn          = module.iam.ecs_task_role_arn
  
  service_a_image = "${module.ecr.repository_urls["service-a"]}:latest"
  service_b_image = "${module.ecr.repository_urls["service-b"]}:latest"
  
  service_a_cpu    = var.service_a_cpu
  service_a_memory = var.service_a_memory
  service_b_cpu    = var.service_b_cpu
  service_b_memory = var.service_b_memory
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_a_name = module.ecs.service_a_name
  ecs_service_b_name = module.ecs.service_b_name
  
  alb_arn_suffix = module.alb.alb_arn_suffix
  target_group_a_arn_suffix = module.alb.target_group_a_arn_suffix
  target_group_b_arn_suffix = module.alb.target_group_b_arn_suffix
  
  alarm_email = var.alarm_email
}
