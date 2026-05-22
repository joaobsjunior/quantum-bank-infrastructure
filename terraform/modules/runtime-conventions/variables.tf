variable "project_name" {
  description = "Project identifier used in cloud resource names."
  type        = string
  default     = "quantum-bank"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "container_images" {
  description = "Container images for the Quantum Bank runtime services."
  type = object({
    backend           = string
    gateway_bootstrap = string
    gateway_banking   = string
  })
}

variable "container_ports" {
  description = "Container ports for the Quantum Bank runtime services."
  type = object({
    backend           = number
    gateway_bootstrap = number
    gateway_banking   = number
  })
  default = {
    backend           = 8080
    gateway_bootstrap = 8080
    gateway_banking   = 8443
  }
}

variable "common_tags" {
  description = "Tags or labels common to every cloud path."
  type        = map(string)
  default     = {}
}
