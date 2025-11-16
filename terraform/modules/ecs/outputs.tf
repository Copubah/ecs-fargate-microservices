output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "service_a_name" {
  description = "Service A name"
  value       = aws_ecs_service.service_a.name
}

output "service_b_name" {
  description = "Service B name"
  value       = aws_ecs_service.service_b.name
}

output "service_a_id" {
  description = "Service A ID"
  value       = aws_ecs_service.service_a.id
}

output "service_b_id" {
  description = "Service B ID"
  value       = aws_ecs_service.service_b.id
}
