provider "google" {
  project = var.project_id
  region  = var.region
}

module "runtime" {
  source = "../modules/runtime-conventions"

  project_name     = var.project_name
  environment      = var.environment
  container_images = var.container_images
  common_tags      = var.common_tags
}

resource "google_service_account" "runtime" {
  account_id   = replace("${module.runtime.name_prefix}-runtime", "_", "-")
  display_name = "Quantum Bank ${var.environment} runtime"
  project      = var.project_id
}

resource "google_cloud_run_v2_service" "service" {
  for_each = module.runtime.services

  name     = "${module.runtime.name_prefix}-${each.value.name}"
  location = var.region
  project  = var.project_id
  ingress  = each.value.internet_facing ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_ONLY"
  labels   = module.runtime.labels

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = each.value.image

      ports {
        container_port = each.value.port
      }

      dynamic "env" {
        for_each = var.runtime_environment

        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}
