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

## Transport Policy

Every internet-facing gateway service is deployed with the TLS terminator
sidecar (`container_images.gateway_tls`, HAProxy + OpenSSL 3.5) in the same
task/pod network namespace; KrakenD binds loopback only. The
`runtime-conventions` module exposes the `tls_terminators` descriptors and the
`pqc_transport` policy: strict values for every service hop (TLS 1.3,
`X25519MLKEM768`, `mldsa65`/`mldsa87`, ML-DSA-87 CA, ML-DSA-65 leaves) and
`compat_*` values the app-facing listeners additionally serve and accept
(ECDSA P-256 identity under an ECDSA P-384 CA, `X25519` fallback group, ECDSA
signature schemes) for peers whose TLS stack cannot verify ML-DSA yet.

The hybrid key exchange and the PKI identities only reach the client if the
cloud ingress passes TLS through to the sidecar instead of terminating it at
the provider edge (no provider today presents ML-DSA certificates, and a
provider-terminated edge would also strip the mutual TLS the banking listener
enforces):

| Path | Ingress | Status |
| --- | --- | --- |
| AWS ECS/Fargate | Task ENI, sidecar publishes the port | Post-quantum end to end (add an NLB in TCP passthrough mode when fronting with a load balancer) |
| Azure Container Apps | `transport = "tcp"` ingress to the sidecar | Post-quantum end to end; client certificates are verified by the sidecar |
| GCP Cloud Run v2 | Managed HTTPS ingress terminates TLS at Google's edge | Requires a TCP passthrough (internal TCP proxy / GKE) in front of the sidecar to be post-quantum; documented limitation |
