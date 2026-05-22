variable "project_name" {
  description = "Project identifier used in resource names."
  type        = string
  default     = "quantum-bank"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure location for Container Apps resources."
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Resource group name created by this root."
  type        = string
  default     = "rg-quantum-bank-dev"
}

variable "container_images" {
  description = "Container images for backend and gateways."
  type = object({
    backend           = string
    gateway_bootstrap = string
    gateway_banking   = string
  })
  default = {
    backend           = "ghcr.io/joaobsjunior/quantum-bank-backend:latest"
    gateway_bootstrap = "ghcr.io/joaobsjunior/quantum-bank-api-gateway:latest"
    gateway_banking   = "ghcr.io/joaobsjunior/quantum-bank-api-gateway:latest"
  }
}

variable "runtime_environment" {
  description = "Non-secret environment variables injected into every service."
  type        = map(string)
  default     = {}
}

variable "min_replicas" {
  description = "Minimum Container Apps replicas."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum Container Apps replicas."
  type        = number
  default     = 2
}

variable "container_cpu" {
  description = "Container CPU cores."
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Container memory."
  type        = string
  default     = "1Gi"
}

variable "common_tags" {
  description = "Additional Azure tags."
  type        = map(string)
  default     = {}
}
