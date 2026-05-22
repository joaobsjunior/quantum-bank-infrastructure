# Quantum Bank Terraform

This directory contains validating Terraform deployment paths for the
containerized Quantum Bank v1 architecture.

The local Docker Compose stack remains the executable security reference. These
cloud roots model the provider-specific deployment paths for the same three
runtime services:

- `backend`
- `gateway-bootstrap`
- `gateway-banking`

## Layout

| Path | Purpose |
| --- | --- |
| `modules/runtime-conventions` | Shared names, tags/labels, and container image/port conventions. |
| `aws` | AWS ECS/Fargate deployment path. |
| `gcp` | Google Cloud Run v2 deployment path. |
| `azure` | Azure Container Apps deployment path. |

## Validation

Run from `infrastructure`:

```sh
scripts/verify-terraform-config.sh
```

The script uses a local `terraform` binary when present. If Terraform is not
installed, it runs `hashicorp/terraform:1.14.1` through Docker.

## Cloud Differences

AWS expects existing VPC subnets and security groups, then creates ECS task
definitions and services. GCP uses Cloud Run v2 services and service accounts.
Azure creates a resource group, Log Analytics workspace, Container Apps
environment, and Container Apps.

mTLS trust material and OAuth2 secrets are intentionally modeled as inputs.
Production state backends, DNS, managed certificates, and secret-manager wiring
belong to environment-specific overlays.
