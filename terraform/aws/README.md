# AWS Terraform Path

The AWS path deploys the Quantum Bank containers to ECS/Fargate.

## Provider

- `hashicorp/aws` pinned to the `~> 6.0` major line.

## Inputs

Provide existing private `subnet_ids` and `security_group_ids`. The root creates
an ECS cluster, per-service log groups, an execution role, task definitions, and
ECS services for:

- backend
- gateway-bootstrap
- gateway-banking

TLS, mTLS trust material, OAuth2 issuer URLs, and secrets are expected to be
provided through environment variables or an environment-specific secrets
overlay.
