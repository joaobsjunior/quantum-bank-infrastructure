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
require_file "${repo_dir}/compose.yaml"
require_file "${repo_dir}/scripts/local-e2e-smoke.sh"
require_executable "${project_root}/pki/scripts/bootstrap-runtime-certs.sh"
require_executable "${repo_dir}/scripts/verify-keycloak-config.sh"

"${repo_dir}/scripts/verify-keycloak-config.sh" >/dev/null
docker compose --env-file "${repo_dir}/.env.example" --profile smoke -f "${repo_dir}/compose.yaml" config >/dev/null

for service in keycloak backend backend-client gateway-bootstrap gateway-banking smoke-tests negative-mtls-tests; do
  require_string "${service}:" "${repo_dir}/compose.yaml"
done

require_string "QUANTUM_BANK_BACKEND_SSL_ENABLED" "${repo_dir}/compose.yaml"
require_string "KC_HOSTNAME: https://keycloak:8443" "${repo_dir}/compose.yaml"
require_string "KC_HTTP_ENABLED: \"false\"" "${repo_dir}/compose.yaml"
require_string "QUANTUM_BANK_MTLS_ENFORCE_GATEWAY_IDENTITY: \"true\"" "${repo_dir}/compose.yaml"
require_string "jwk_local_ca" "${project_root}/api-gateway/krakend-banking.json"
require_string "qos/ratelimit/router" "${project_root}/api-gateway/krakend-bootstrap.json"
require_string "mobile-smoke-enroll.csr" "${repo_dir}/compose.yaml"

# No plaintext issuer endpoint and no disabled JWK transport security anywhere.
for forbidden in "http://keycloak:8080" "disable_jwk_security"; do
  if grep -RIn --exclude-dir=.git --exclude-dir=docs -- "${forbidden}" "${repo_dir}/compose.yaml" "${repo_dir}/scripts" "${project_root}/api-gateway"/*.json "${project_root}/backend/src/main/resources" "${project_root}/backend-client/src/main/resources"; then
    echo "forbidden plaintext/insecure issuer configuration found: ${forbidden}" >&2
    exit 1
  fi
done
require_string "root-ca.crt" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"input_headers\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"Authorization\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"output_encoding\": \"no-op\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"scopes_key\": \"scope\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"profile:write\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "mobile-smoke-client.crt" "${repo_dir}/compose.yaml"
require_string "BACKEND_DIRECT_URL" "${repo_dir}/scripts/local-e2e-smoke.sh"

echo "local-e2e-config-ok"
