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

variable "aws_region" {
  description = "AWS region for the ECS runtime."
  type        = string
  default     = "us-east-1"
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

variable "subnet_ids" {
  description = "Existing private subnet IDs for ECS services."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Existing security group IDs for ECS services."
  type        = list(string)
  default     = []
}

variable "desired_count" {
  description = "Desired task count for each service."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "runtime_environment" {
  description = "Non-secret environment variables injected into every service."
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Additional AWS tags."
  type        = map(string)
  default     = {}
}
