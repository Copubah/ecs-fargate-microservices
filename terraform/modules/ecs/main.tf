# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "service_a" {
  name              = "/ecs/${var.project_name}-service-a"
  retention_in_days = 7

  kms_key_id = aws_kms_key.logs.arn
}

resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/${var.project_name}-service-b"
  retention_in_days = 7

  kms_key_id = aws_kms_key.logs.arn
}

# KMS Key for Log Encryption
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ECS Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow from ALB to Service A"
  }

  ingress {
    from_port       = 8001
    to_port         = 8001
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow from ALB to Service B"
  }

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    self        = true
    description = "Allow Service A to Service B"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }
}

# Task Definition for Service A
resource "aws_ecs_task_definition" "service_a" {
  family                   = "${var.project_name}-service-a"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.service_a_cpu
  memory                   = var.service_a_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name  = "service-a"
    image = var.service_a_image

    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]

    environment = [{
      name  = "SERVICE_B_URL"
      value = "http://service-b.local:8001"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service_a.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# Task Definition for Service B
resource "aws_ecs_task_definition" "service_b" {
  family                   = "${var.project_name}-service-b"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.service_b_cpu
  memory                   = var.service_b_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name  = "service-b"
    image = var.service_b_image

    portMappings = [{
      containerPort = 8001
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service_b.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8001/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "local"
  vpc  = var.vpc_id
}

# Service Discovery for Service B
resource "aws_service_discovery_service" "service_b" {
  name = "service-b"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ECS Service A
resource "aws_ecs_service" "service_a" {
  name            = "${var.project_name}-service-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_a.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_a_arn
    container_name   = "service-a"
    container_port   = 8000
  }

  depends_on = [var.alb_target_group_a_arn]
}

# ECS Service B
resource "aws_ecs_service" "service_b" {
  name            = "${var.project_name}-service-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_b.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_b_arn
    container_name   = "service-b"
    container_port   = 8001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service_b.arn
  }

  depends_on = [var.alb_target_group_b_arn]
}

# Auto Scaling Target for Service A
resource "aws_appautoscaling_target" "service_a" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service_a.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU for Service A
resource "aws_appautoscaling_policy" "service_a_cpu" {
  name               = "${var.project_name}-service-a-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_a.resource_id
  scalable_dimension = aws_appautoscaling_target.service_a.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_a.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Memory for Service A
resource "aws_appautoscaling_policy" "service_a_memory" {
  name               = "${var.project_name}-service-a-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_a.resource_id
  scalable_dimension = aws_appautoscaling_target.service_a.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_a.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Service B
resource "aws_appautoscaling_target" "service_b" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service_b.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU for Service B
resource "aws_appautoscaling_policy" "service_b_cpu" {
  name               = "${var.project_name}-service-b-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_b.resource_id
  scalable_dimension = aws_appautoscaling_target.service_b.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_b.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Memory for Service B
resource "aws_appautoscaling_policy" "service_b_memory" {
  name               = "${var.project_name}-service-b-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_b.resource_id
  scalable_dimension = aws_appautoscaling_target.service_b.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_b.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70.0
  }
}
