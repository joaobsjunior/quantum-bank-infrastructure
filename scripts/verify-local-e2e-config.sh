#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
project_root="$(cd "${repo_dir}/.." && pwd)"

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "missing ${path}" >&2
    exit 1
  fi
}

require_executable() {
  local path="$1"
  if [[ ! -x "${path}" ]]; then
    echo "missing executable ${path}" >&2
    exit 1
  fi
}

require_string() {
  local value="$1"
  local path="$2"
  if ! grep -Fq "${value}" "${path}"; then
    echo "missing required value '${value}' in ${path}" >&2
    exit 1
  fi
}

require_file "${project_root}/backend/Dockerfile"
require_file "${project_root}/api-gateway/Dockerfile"
require_file "${project_root}/api-gateway/Dockerfile.tls"
require_file "${project_root}/api-gateway/tls/haproxy-bootstrap.cfg"
require_file "${project_root}/api-gateway/tls/haproxy-banking.cfg"
require_file "${repo_dir}/compose.yaml"
require_file "${repo_dir}/keycloak/haproxy-keycloak.cfg"
require_file "${repo_dir}/scripts/local-e2e-smoke.sh"
require_executable "${project_root}/pki/scripts/bootstrap-runtime-certs.sh"
require_executable "${project_root}/pki/scripts/pqc-handshake-tests.sh"
require_executable "${project_root}/api-gateway/scripts/verify-pqc-gateway.sh"
require_executable "${repo_dir}/scripts/verify-keycloak-config.sh"

"${repo_dir}/scripts/verify-keycloak-config.sh" >/dev/null
"${project_root}/api-gateway/scripts/verify-pqc-gateway.sh" >/dev/null
docker compose --env-file "${repo_dir}/.env.example" --profile smoke -f "${repo_dir}/compose.yaml" config >/dev/null

for service in keycloak keycloak-tls backend backend-client gateway-bootstrap gateway-bootstrap-tls gateway-banking gateway-banking-tls smoke-tests negative-mtls-tests pqc-handshake-tests; do
  require_string "${service}:" "${repo_dir}/compose.yaml"
done

# Every TLS socket that crosses a container boundary is post-quantum: the
# issuer and both gateway listeners are fronted by HAProxy terminators sharing
# their network namespace, and the paired process only listens on loopback.
require_string "QUANTUM_BANK_BACKEND_SSL_ENABLED" "${repo_dir}/compose.yaml"
require_string "KC_HOSTNAME: https://keycloak:8443" "${repo_dir}/compose.yaml"
require_string "KC_HTTP_HOST: 127.0.0.1" "${repo_dir}/compose.yaml"
require_string "KC_PROXY_HEADERS: xforwarded" "${repo_dir}/compose.yaml"
require_string "KC_HEALTH_ENABLED: \"false\"" "${repo_dir}/compose.yaml"
require_string "network_mode: \"service:keycloak\"" "${repo_dir}/compose.yaml"
require_string "network_mode: \"service:gateway-bootstrap\"" "${repo_dir}/compose.yaml"
require_string "network_mode: \"service:gateway-banking\"" "${repo_dir}/compose.yaml"
require_string "haproxy-keycloak.cfg" "${repo_dir}/compose.yaml"
require_string "haproxy-bootstrap.cfg" "${repo_dir}/compose.yaml"
require_string "haproxy-banking.cfg" "${repo_dir}/compose.yaml"
require_string "pqc-handshake-tests.sh" "${repo_dir}/compose.yaml"
require_string "QUANTUM_BANK_MTLS_ENFORCE_GATEWAY_IDENTITY: \"true\"" "${repo_dir}/compose.yaml"
require_string "qos/ratelimit/router" "${project_root}/api-gateway/krakend-bootstrap.json"
require_string "mobile-smoke-enroll.csr" "${repo_dir}/compose.yaml"
require_string "mobile-smoke-enroll-compat.csr" "${repo_dir}/compose.yaml"
require_string "mobile-smoke-client.crt" "${repo_dir}/compose.yaml"
require_string "mobile-smoke-client-compat.crt" "${repo_dir}/compose.yaml"
require_string "trust-anchors.crt" "${repo_dir}/compose.yaml"
require_string "root-ca-compat.crt" "${repo_dir}/compose.yaml"
require_string "classical-client.crt" "${repo_dir}/compose.yaml"
require_string "mldsa44-client.crt" "${repo_dir}/compose.yaml"
require_string "untrusted-compat-client.crt" "${repo_dir}/compose.yaml"
require_string "BACKEND_DIRECT_URL" "${repo_dir}/scripts/local-e2e-smoke.sh"
require_string "COMPAT_MOBILE_ENROLL_CSR" "${repo_dir}/scripts/local-e2e-smoke.sh"

# The issuer terminator is an app-facing dual-identity listener: the ECDSA
# compatibility certificate first (no-SNI default) and the ML-DSA certificate
# second, hybrid ML-KEM group preferred with X25519 accepted, ML-DSA and ECDSA
# signature schemes only (never RSA), TLS 1.3 only, and forwarded-proto so
# Keycloak keeps sslRequired=all satisfied behind the loopback hop.
keycloak_tls="${repo_dir}/keycloak/haproxy-keycloak.cfg"
require_string "bind :8443 ssl crt /etc/quantum-bank/tls/keycloak-server-compat.pem crt /etc/quantum-bank/tls/keycloak-server.pem" "${keycloak_tls}"
require_string "ssl-default-bind-options ssl-min-ver TLSv1.3 ssl-max-ver TLSv1.3" "${keycloak_tls}"
require_string "ssl-default-bind-curves X25519MLKEM768:X25519" "${keycloak_tls}"
require_string "ssl-default-bind-sigalgs mldsa65:mldsa87:ecdsa_secp256r1_sha256:ecdsa_secp384r1_sha384" "${keycloak_tls}"
require_string "http-request set-header X-Forwarded-Proto https" "${keycloak_tls}"
require_string "server keycloak 127.0.0.1:8080" "${keycloak_tls}"
if grep -Eq 'rsa_|ed25519|verify (none|optional)|crt-ignore-err' "${keycloak_tls}"; then
  echo "forbidden TLS setting in ${keycloak_tls}" >&2
  exit 1
fi

# No plaintext issuer endpoint, no JVM-terminated issuer TLS (Keycloak cannot
# do ML-DSA) and no KrakenD-side trust anchors anywhere. This script is
# excluded from the scan so the check can never match its own source.
for forbidden in "http://keycloak:8080" "KC_HTTPS_" "jwk_local_ca"; do
  if grep -RIn --exclude-dir=.git --exclude-dir=docs --exclude="$(basename "${BASH_SOURCE[0]}")" -- "${forbidden}" \
    "${repo_dir}/compose.yaml" "${repo_dir}/scripts" "${project_root}/api-gateway"/*.json \
    "${project_root}/backend/src/main/resources" "${project_root}/backend-client/src/main/resources"; then
    echo "forbidden plaintext/classical issuer configuration found: ${forbidden}" >&2
    exit 1
  fi
done
require_string "\"input_headers\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"Authorization\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"output_encoding\": \"no-op\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"scopes_key\": \"scope\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"profile:write\"" "${project_root}/api-gateway/krakend-banking.json"

echo "local-e2e-config-ok"
