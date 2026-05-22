locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.common_tags,
  )

  labels = {
    for key, value in local.tags :
    replace(lower(key), "_", "-") => replace(lower(value), "_", "-")
  }

  services = {
    backend = {
      name             = "backend"
      image            = var.container_images.backend
      port             = var.container_ports.backend
      internet_facing  = false
      requires_mtls    = true
      requires_oauth2  = true
      healthcheck_path = "/actuator/health"
    }
    gateway_bootstrap = {
      name             = "gateway-bootstrap"
      image            = var.container_images.gateway_bootstrap
      port             = var.container_ports.gateway_bootstrap
      internet_facing  = true
      requires_mtls    = false
      requires_oauth2  = true
      healthcheck_path = "/__health"
    }
    gateway_banking = {
      name             = "gateway-banking"
      image            = var.container_images.gateway_banking
      port             = var.container_ports.gateway_banking
      internet_facing  = true
      requires_mtls    = true
      requires_oauth2  = true
      healthcheck_path = "/__health"
    }
  }
}
