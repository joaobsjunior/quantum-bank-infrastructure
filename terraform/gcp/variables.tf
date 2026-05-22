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

variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
  default     = "quantum-bank-dev"
}

variable "region" {
  description = "Google Cloud region for Cloud Run services."
  type        = string
  default     = "us-central1"
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

variable "min_instances" {
  description = "Minimum Cloud Run instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum Cloud Run instances."
  type        = number
  default     = 2
}

variable "common_tags" {
  description = "Additional labels."
  type        = map(string)
  default     = {}
}
