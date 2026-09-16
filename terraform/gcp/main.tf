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

    # Internet-facing services: the post-quantum TLS terminator sidecar is the
    # ingress container; KrakenD binds loopback only. NOTE: Cloud Run's managed
    # ingress terminates TLS at Google's edge with classical certificates, so
    # this path is post-quantum only behind a TCP passthrough (for example an
    # internal TCP proxy load balancer to the terminator); see README.
    containers {
      image = each.value.image

      dynamic "ports" {
        for_each = each.value.internet_facing ? [] : [each.value.port]

        content {
          container_port = ports.value
        }
      }

      dynamic "env" {
        for_each = var.runtime_environment

        content {
          name  = env.key
          value = env.value
        }
      }
    }

    dynamic "containers" {
      for_each = contains(keys(module.runtime.tls_terminators), each.key) ? [module.runtime.tls_terminators[each.key]] : []

      content {
        name    = containers.value.name
        image   = containers.value.image
        command = containers.value.command

        ports {
          container_port = containers.value.port
        }
      }
    }
  }
}
