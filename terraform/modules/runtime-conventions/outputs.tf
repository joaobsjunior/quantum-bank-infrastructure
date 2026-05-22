output "name_prefix" {
  description = "Common prefix for cloud resource names."
  value       = local.name_prefix
}

output "tags" {
  description = "Common tag map."
  value       = local.tags
}

output "labels" {
  description = "Common label map normalized for providers that require lowercase labels."
  value       = local.labels
}

output "services" {
  description = "Normalized Quantum Bank service descriptors."
  value       = local.services
}
