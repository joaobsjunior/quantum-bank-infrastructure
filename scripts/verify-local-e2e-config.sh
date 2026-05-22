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

for service in keycloak backend gateway-bootstrap gateway-banking smoke-tests; do
  require_string "${service}:" "${repo_dir}/compose.yaml"
done

require_string "QUANTUM_BANK_BACKEND_SSL_ENABLED" "${repo_dir}/compose.yaml"
require_string "KC_HOSTNAME: http://keycloak:8080" "${repo_dir}/compose.yaml"
require_string "root-ca.crt" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"input_headers\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"Authorization\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"output_encoding\": \"no-op\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"scopes_key\": \"scope\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "\"profile:write\"" "${project_root}/api-gateway/krakend-banking.json"
require_string "mobile-smoke-client.crt" "${repo_dir}/compose.yaml"
require_string "BACKEND_DIRECT_URL" "${repo_dir}/scripts/local-e2e-smoke.sh"

echo "local-e2e-config-ok"
