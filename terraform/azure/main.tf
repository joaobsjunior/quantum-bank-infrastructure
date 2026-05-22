provider "azurerm" {
  features {}
}

module "runtime" {
  source = "../modules/runtime-conventions"

  project_name     = var.project_name
  environment      = var.environment
  container_images = var.container_images
  common_tags      = var.common_tags
}

resource "azurerm_resource_group" "runtime" {
  name     = var.resource_group_name
  location = var.location
  tags     = module.runtime.tags
}

resource "azurerm_log_analytics_workspace" "runtime" {
  name                = replace("${module.runtime.name_prefix}-logs", "-", "")
  location            = azurerm_resource_group.runtime.location
  resource_group_name = azurerm_resource_group.runtime.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = module.runtime.tags
}

resource "azurerm_container_app_environment" "runtime" {
  name                       = "${module.runtime.name_prefix}-apps"
  location                   = azurerm_resource_group.runtime.location
  resource_group_name        = azurerm_resource_group.runtime.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.runtime.id
  tags                       = module.runtime.tags
}

resource "azurerm_container_app" "service" {
  for_each = module.runtime.services

  name                         = "${module.runtime.name_prefix}-${each.value.name}"
  container_app_environment_id = azurerm_container_app_environment.runtime.id
  resource_group_name          = azurerm_resource_group.runtime.name
  revision_mode                = "Single"
  tags                         = module.runtime.tags

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = each.value.name
      image  = each.value.image
      cpu    = var.container_cpu
      memory = var.container_memory

      dynamic "env" {
        for_each = var.runtime_environment

        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  dynamic "ingress" {
    for_each = each.value.internet_facing ? [each.value] : []

    content {
      external_enabled           = true
      target_port                = ingress.value.port
      transport                  = "auto"
      client_certificate_mode    = ingress.value.requires_mtls ? "require" : "ignore"
      allow_insecure_connections = false

      traffic_weight {
        percentage      = 100
        latest_revision = true
      }
    }
  }
}
