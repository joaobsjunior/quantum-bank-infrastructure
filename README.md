# Quantum Bank Infrastructure

Terraform and deployment assets for Quantum Bank.

Initial responsibilities:

- Local environment orchestration for backend and API Gateway
- Terraform deployment paths for AWS, GCP, and Azure
- Environment variables, secrets wiring, and deployment documentation

## Phase 1 Contract Ownership

Infrastructure owns and consumes this Phase 1 contract:

- [Local Runtime Checklist](docs/contracts/local-runtime-checklist.md) for CONT-01 and CONT-02 local service, trust material, environment variable, gateway path, security failure, and banking flow handoffs.

Later Compose and deployment work must prove the gateway, backend, PKI, OAuth2 issuer, H2-backed backend runtime, and mTLS trust material work together before UI flows are considered end-to-end.

## Phase 2 OAuth2 Runtime

Infrastructure owns the local Keycloak issuer for AUTH-01:

- [OAuth2 Local Issuer Contract](docs/contracts/oauth2-local-issuer.md) defines the `quantum-bank-local` realm, app client, local test client, seed user, issuer URLs, JWKS path, scopes, and audience.
- [compose.yaml](compose.yaml) starts Keycloak on `http://localhost:8180` so the gateway can keep `http://localhost:8080`.
- [verify-keycloak-config.sh](scripts/verify-keycloak-config.sh) checks the local issuer source config before gateway or backend validation consumes it.
