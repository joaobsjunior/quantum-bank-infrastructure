# Local Runtime Checklist

Requirements: CONT-01, CONT-02, MTLS-01, MTLS-02

Owner: Quantum Bank Infrastructure

This checklist records the local runtime contract that later Compose and
deployment phases must satisfy before the app can be called end-to-end through
the gateway and backend.

## Required Services

The local runtime must provide these services:

- `api-gateway`
- `backend`
- `pki`
- `oauth2-issuer`
- `h2-backed backend runtime`

The services may run as local processes or containers in later phases, but the
contract requires the same dependency shape: mobile traffic enters through the
gateway, backend owns business and OTK logic, PKI owns certificate lifecycle,
and the OAuth2 issuer provides bearer tokens for gateway validation.

## Required Trust Material

The local runtime must provide trust material for:

- App-to-gateway mTLS trust anchor.
- Gateway-to-backend mTLS trust anchor.
- Mobile client certificate chain issued through the CSR flow.
- Gateway trust store or secret location.
- Backend trust store or secret location when gateway-to-backend mTLS is active.
- PKI CA material for local v1 only.

Trust material is owned by PKI and consumed by infrastructure runtime wiring.
KrakenD consumes and enforces certificates but does not own certificate
issuance, renewal, or revocation.

## Required Environment Variables

Later runtime work must define environment variables or equivalent config for:

- Gateway base URL.
- Backend internal base URL.
- OAuth2 issuer URL.
- OAuth2 audience.
- OAuth2 JWKS or token validation source.
- PKI service base URL or local integration path.
- Certificate profile, initially `quantum-bank-mobile-client-v1`.
- H2 database mode for the backend.
- Problem-details correlation id propagation.

The exact variable names may be chosen in implementation phases, but the
runtime must expose enough configuration to verify CONT-01 and CONT-02 without
hard-coded secrets or direct mobile-to-backend access.

## Gateway Paths

The local runtime must expose these gateway paths:

- Bootstrap listener `8080`:
  - `POST /auth/otk`
  - `POST /auth/csr`
- Banking listener `8443`:
  - `POST /pix/transfers`
  - `GET /statements`
  - `GET /profile`

The paths must match `api-gateway/openapi/quantum-bank-v1.yaml`.

## Phase 3 mTLS Runtime Wiring

Phase 3 records source-level wiring for local mTLS. Phase 6 owns full
Dockerized service startup.

- Gateway bootstrap config: `api-gateway/krakend-bootstrap.json` on port `8080`.
- Gateway banking config: `api-gateway/krakend-banking.json` on port `8443`.
- App-to-gateway banking trust anchor: `pki/local-ca/trust/issuing-ca.crt`.
- Gateway client certificate: `GATEWAY_CLIENT_CERT`.
- Gateway client private key: `GATEWAY_CLIENT_KEY`.
- Backend server key store: `BACKEND_SERVER_KEY_STORE`.
- Backend trust store: `BACKEND_TRUST_STORE`.
- Backend mTLS port: `BACKEND_MTLS_PORT`, local default `8080`.
- Backend transport client-auth policy: `client-auth=NEED`.

Trust anchors are public PKI artifacts. Private key material and generated
keystores remain local runtime files and are not committed.

## Security Failure Checks

Later end-to-end verification must include these security failures:

- `missing token`
- `invalid token`
- `missing client certificate`
- `untrusted client certificate`
- `OTK replay`

Each failure must return `application/problem+json` with a stable `errorCode`
and `correlationId` when the request reaches the app-facing API boundary.

D-27 negative mTLS matrix:

| Case | Boundary | Expected result |
| --- | --- | --- |
| missing client cert | app-to-gateway banking listener `8443` | TLS alert or handshake failure |
| untrusted client cert | app-to-gateway banking listener `8443` | TLS alert or handshake failure |
| expired client cert | app-to-gateway banking listener `8443` | TLS alert or handshake failure |
| wrong-environment trust anchor | app-to-gateway banking listener `8443` | TLS alert or handshake failure |
| direct backend without gateway client certificate | gateway-to-backend mTLS port | TLS alert or handshake failure |

The source script `pki/scripts/negative-mtls-tests.sh` exercises this matrix and
prints `negative-mtls-ok` only when every case fails closed. If services are not
running, it exits with a prerequisite message instead of passing.

## Banking Flow Checks

Later end-to-end verification must include these banking flows:

- OAuth2-authenticated OTK issue through `POST /auth/otk`.
- CSR submission through `POST /auth/csr`.
- Pix transfer simulation with scenario `SUCCESS`.
- Pix transfer simulation with scenario `ERROR`.
- Statement retrieval through `GET /statements`.
- Customer registration data retrieval through `GET /profile`.

The Pix `SUCCESS` and `ERROR` paths must be deterministic so automated tests can
exercise both user journeys.

## Later Phase Ownership

Phase 2 owns OAuth2/JWT configuration and backend authentication integration.

Phase 3 owns mTLS configuration, certificate consumption, and trust wiring.

Phase 4 owns backend endpoints, H2-backed backend runtime behavior, and Pix
success/error simulation.

Phase 5 owns mobile API clients, certificate readiness checks, and screen flows.

Phase 6 owns Compose or local orchestration.

Phase 7 owns cross-repo end-to-end verification.

## Preserved Verification Commands

Run these commands from the superproject root after later phases modify the
contracts or runtime:

```sh
rg "CONT-01" backend/docs/contracts/otk-csr-contract.md pki/docs/contracts/certificate-lifecycle.md mobile-app/docs/contracts/client-bootstrap.md infrastructure/docs/contracts/local-runtime-checklist.md
rg "CONT-02" api-gateway/docs/contracts/gateway-boundary.md backend/docs/contracts/api-implementation-map.md mobile-app/docs/contracts/api-client-contract.md infrastructure/docs/contracts/local-runtime-checklist.md
ruby -e "require 'yaml'; YAML.load_file('api-gateway/openapi/quantum-bank-v1.yaml'); puts 'openapi-yaml-ok'"
rg "Phase 1 Contract Ownership" mobile-app/README.md backend/README.md api-gateway/README.md pki/README.md infrastructure/README.md
```
