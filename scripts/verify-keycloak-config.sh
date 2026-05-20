#!/usr/bin/env bash
set -euo pipefail

realm_file="keycloak/quantum-bank-local-realm.json"

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
)

for value in "${required_strings[@]}"; do
  if ! grep -Fq "${value}" "${realm_file}"; then
    echo "missing required Keycloak value: ${value}" >&2
    exit 1
  fi
done

echo "keycloak-config-ok"
