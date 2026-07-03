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

## Phase 6 Local E2E Runtime

Phase 6 expands [compose.yaml](compose.yaml) into the local end-to-end runtime:
Keycloak, Spring Boot backend, KrakenD bootstrap listener, KrakenD banking
listener, and an optional smoke-test container. Generate runtime certificates
before starting Compose:

```sh
../pki/scripts/bootstrap-runtime-certs.sh
docker compose --env-file .env.example build
docker compose --env-file .env.example up -d keycloak backend gateway-bootstrap gateway-banking
docker compose --env-file .env.example --profile smoke run --rm smoke-tests
```

The backend is reachable only inside the Compose network. App-facing traffic
uses KrakenD bootstrap on `8080` and banking on `8443`; banking routes require
OAuth2 and app-to-gateway mTLS.

## Testing & CI

- Validate infrastructure config locally: `./scripts/ci-validate.sh` runs
  `terraform fmt -check` + `terraform validate` for aws/gcp/azure (local binary
  or the `hashicorp/terraform` Docker image) plus the Keycloak and local-e2e
  config checks.
- Runtime smoke (`scripts/local-e2e-smoke.sh`) is excluded from the static gate;
  it runs in the superproject's opt-in `e2e` job.
- CI (`.github/workflows/ci.yml`) runs the validation gate on every push/PR to
  `main`.

## Runtime Requirements (full local stack)

`compose.yaml` sets no `deploy.resources` limits, so the numbers below are
recommendations for running the whole stack locally (`keycloak` + `backend` +
both KrakenD gateways). The optional `smoke-tests` container is ephemeral.

| Service | Image | Memory (idle → peak) | CPU | Disk |
| --- | --- | --- | --- | --- |
| keycloak | keycloak:26.5.6 | ~450 MB → ~900 MB (startup + realm import) | 0.5–2 vCPU | dev mode, in-memory (no volume) |
| backend | temurin 17-jre | ~400 MB → ~1 GB | 0.5–1 vCPU | in-memory H2 (no DB volume) |
| gateway-bootstrap | krakend:2.13.4 | ~30–120 MB | 0.25–0.5 vCPU | config + read-only TLS mounts |
| gateway-banking | krakend:2.13.4 (same image) | ~30–120 MB | 0.25–0.5 vCPU | config + read-only TLS mounts |
| smoke-tests (opt) | curlimages/curl:8.16.0 | ~10–20 MB (ephemeral) | negligible | script + read-only cert mounts |

**Aggregate to run the stack comfortably:**

- **Memory:** ~2.5–3.5 GB steady; up to ~4 GB during startup and the backend
  image build. Allocate **≥4 GB** to Docker.
- **CPU:** **2+ vCPU** (4 speeds up the backend Gradle build and Keycloak boot).
- **Disk:** images ~1.0–1.3 GB + backend Gradle build cache ~0.5–1.5 GB → keep
  **≥4 GB free**.

The heaviest one-off cost is the backend image build (a full Gradle `bootJar`
inside Docker). The KrakenD gateways are the lightest services (small Go
binaries). `mobile-app` (Flutter client) and `pki` (scripts + local CA mounted
as volumes) are not Compose services — see their READMEs.
