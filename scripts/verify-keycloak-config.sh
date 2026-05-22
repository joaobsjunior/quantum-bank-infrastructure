#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
realm_file="${repo_dir}/keycloak/quantum-bank-local-realm.json"

if [[ ! -f "${realm_file}" ]]; then
  echo "missing ${realm_file}" >&2
  exit 1
fi

ruby -e "require 'json'; JSON.parse(File.read('${realm_file}'))"

required_strings=(
  "quantum-bank-local"
  "quantum-bank-mobile"
  "quantum-bank-test"
  "alice@quantumbank.local"
  "quantum-bank-api"
  "pix:write"
  "statements:read"
  "profile:read"
  "profile:write"
)

for value in "${required_strings[@]}"; do
  if ! grep -Fq "${value}" "${realm_file}"; then
    echo "missing required Keycloak value: ${value}" >&2
    exit 1
  fi
done

echo "keycloak-config-ok"
