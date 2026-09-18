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

  # TLS terminator paired with every internet-facing service. It shares the
  # service's network namespace (task/pod), owns the published port as an
  # app-facing dual-identity listener (PKI-issued ML-DSA-65 certificate for
  # post-quantum peers, ECDSA P-256 compatibility certificate otherwise;
  # X25519MLKEM768 preferred, X25519 accepted) and keeps its egress strict; the
  # paired KrakenD process listens on loopback only. The cloud ingress in front
  # of it must pass TLS through (no provider-edge termination) so the hybrid
  # key exchange and the PKI identities reach the client.
  tls_terminators = {
    for key, service in local.services : key => {
      name    = "${service.name}-tls"
      image   = var.container_images.gateway_tls
      port    = service.port
      command = ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy-${replace(service.name, "gateway-", "")}.cfg"]
      policy  = var.pqc_transport
    } if service.internet_facing
  }
}
