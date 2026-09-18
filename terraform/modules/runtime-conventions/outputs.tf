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

output "tls_terminators" {
  description = "TLS terminator sidecar descriptors (post-quantum first, compatibility chain on the app edge) keyed by the internet-facing service they front."
  value       = local.tls_terminators
}

output "pqc_transport" {
  description = "TLS policy every network hop must satisfy (strict values for service hops, compat_* values additionally accepted on app-facing listeners)."
  value       = var.pqc_transport
}
