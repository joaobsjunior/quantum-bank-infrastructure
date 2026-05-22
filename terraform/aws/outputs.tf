output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.runtime.name
}

output "service_names" {
  description = "ECS service names by Quantum Bank service key."
  value = {
    for key, service in aws_ecs_service.service : key => service.name
  }
}

output "task_definition_families" {
  description = "Task definition families by Quantum Bank service key."
  value = {
    for key, task in aws_ecs_task_definition.service : key => task.family
  }
}
