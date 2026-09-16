# OAuth2 Local Issuer Contract

Requirement: AUTH-01

Owner: Quantum Bank Infrastructure

This contract defines the local v1 OAuth2/OIDC issuer used by the mobile app,
KrakenD, and backend security tests.

## Issuer Runtime

The local v1 issuer is Keycloak.

Keycloak runs from `infrastructure/compose.yaml` using the imported realm file
`infrastructure/keycloak/quantum-bank-local-realm.json`.

Host-facing issuer URL:

- `https://localhost:8180/realms/quantum-bank-local`

Container-network issuer URL:

- `https://keycloak:8443/realms/quantum-bank-local`

JWKS path:

- `/protocol/openid-connect/certs`

The gateway keeps local origin `http://localhost:8080`. Keycloak must not use
host port `8080` in Phase 2.

## Realm And Clients

Realm:

- `quantum-bank-local`

Official mobile app client:

- `quantum-bank-mobile`
- Public client.
- Authorization Code + PKCE.
- PKCE method `S256`.
- Direct access grants disabled.

Local test client:

- `quantum-bank-test`
- Local test-only.
- Not an app authentication path.
- Must not appear in mobile configuration.

Seed user:

- `alice@quantumbank.local`

## Token Claims

Accepted tokens must carry:

- `iss`
- `sub`
- `aud`
- `exp`
- `iat`
- `azp`
- `scope`

Gateway and backend consumers must reject tokens that are missing required
claims or that fail issuer, audience, expiration, or scope checks.

## Scopes And Audience

Accepted audience:

- `quantum-bank-api`

Local v1 scopes:

- `openid`
- `profile`
- `pix:write`
- `statements:read`
- `profile:read`

Endpoint scope ownership remains in the gateway and backend policy contracts.

## Local Test Boundaries

The `quantum-bank-test` client exists only to make local HTTP and integration
tests practical.

JWT fixtures may be used only in unit tests. Integration tests must use the
local issuer path or the isolated local test client.

The mobile app must use `quantum-bank-mobile` and Authorization Code + PKCE.

## Gateway And Backend Consumers

KrakenD validates app-facing JWTs using the container-network issuer and JWKS:

- Issuer: `https://keycloak:8443/realms/quantum-bank-local`
- JWKS: `https://keycloak:8443/realms/quantum-bank-local/protocol/openid-connect/certs`

Backend validation may use host-facing values in tests and container-network
values in Compose:

- Issuer: `https://localhost:8180/realms/quantum-bank-local`
- JWKS: `https://localhost:8180/realms/quantum-bank-local/protocol/openid-connect/certs`

Both consumers must validate audience `quantum-bank-api`.

## Out Of Scope

Phase 2 does not implement:

- Production identity provider hardening.
- MFA or passkeys.
- Real customer identity lifecycle.
- mTLS certificate issuance.
- Profile editing with `profile:write`.

## Post-Quantum Terminator

Keycloak cannot present ML-DSA certificates (JDK 21 JSSE), so it runs on
`127.0.0.1:8080` in production mode with `--proxy-headers xforwarded`, and the
`keycloak-tls` HAProxy sidecar in the same network namespace owns
`https://keycloak:8443` with the PKI-issued ML-DSA-65 certificate, TLS 1.3,
`X25519MLKEM768` and `mldsa65:mldsa87` only. Tokens, JWKs and issuer metadata
therefore never cross a container or host boundary outside a post-quantum TLS
session; the loopback hop never leaves the namespace.
