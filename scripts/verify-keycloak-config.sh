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
ruby - "${realm_file}" <<'RUBY'
require 'json'

realm = JSON.parse(File.read(ARGV.fetch(0)))
clients = realm.fetch('clients')
mobile = clients.find { |client| client['clientId'] == 'quantum-bank-mobile' }
abort 'missing quantum-bank-mobile client' if mobile.nil?
abort 'quantum-bank-mobile must remain a public client' unless mobile['publicClient'] == true
abort 'quantum-bank-mobile must enable directAccessGrantsEnabled for local simulator login' unless mobile['directAccessGrantsEnabled'] == true

required_default_scopes = %w[
  quantum-bank-api-audience
  pix:write
  statements:read
  profile:read
  profile:write
]
default_scopes = mobile.fetch('defaultClientScopes')
missing = required_default_scopes - default_scopes
abort "quantum-bank-mobile missing default scopes: #{missing.join(', ')}" unless missing.empty?

preferred_username_mapper = mobile.fetch('protocolMappers', []).find do |mapper|
  mapper['protocolMapper'] == 'oidc-usermodel-property-mapper' &&
    mapper.dig('config', 'claim.name') == 'preferred_username' &&
    mapper.dig('config', 'access.token.claim') == 'true'
end
abort 'quantum-bank-mobile must map preferred_username into access tokens' if preferred_username_mapper.nil?

test_client = clients.find { |client| client['clientId'] == 'quantum-bank-test' }
abort 'missing quantum-bank-test client' if test_client.nil?
abort 'quantum-bank-test must remain confidential' unless test_client['publicClient'] == false
RUBY

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
