output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.runtime.name
}

output "container_app_names" {
  description = "Container App names by Quantum Bank service key."
  value = {
    for key, app in azurerm_container_app.service : key => app.name
  }
}

output "container_app_fqdns" {
  description = "Container App FQDNs for internet-facing services."
  value = {
    for key, app in azurerm_container_app.service : key => app.ingress[0].fqdn
    if length(app.ingress) > 0
  }
}
