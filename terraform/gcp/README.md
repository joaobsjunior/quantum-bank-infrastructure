# GCP Terraform Path

The GCP path deploys the Quantum Bank containers to Cloud Run v2.

## Provider

- `hashicorp/google` pinned to the `~> 7.0` major line.

## Inputs

Set `project_id` and `region` for the target environment. The root creates a
runtime service account and one Cloud Run v2 service for each runtime service.

`backend` is marked internal-only. Gateway services are internet-facing at the
Cloud Run layer; production mTLS and certificate policies should be added with
an external HTTPS Load Balancer, Certificate Manager, and service-to-service IAM
bindings in an environment overlay.
