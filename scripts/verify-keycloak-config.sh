#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
realm_file="${repo_dir}/keycloak/quantum-bank-local-realm.json"

if [[ ! -f "${realm_file}" ]]; then
  echo "missing ${realm_file}" >&2
  exit 1
fi

python3 - "${realm_file}" <<'PY'
import json, sys

realm = json.load(open(sys.argv[1]))
clients = realm["clients"]
mobile = next((c for c in clients if c.get("clientId") == "quantum-bank-mobile"), None)
if mobile is None:
    sys.exit("missing quantum-bank-mobile client")
if mobile.get("publicClient") is not True:
    sys.exit("quantum-bank-mobile must remain a public client")
if mobile.get("directAccessGrantsEnabled") is not True:
    sys.exit("quantum-bank-mobile must enable directAccessGrantsEnabled for local simulator login")

required_default_scopes = ["quantum-bank-api-audience", "pix:write", "statements:read", "profile:read", "profile:write"]
default_scopes = mobile["defaultClientScopes"]
missing = [s for s in required_default_scopes if s not in default_scopes]
if missing:
    sys.exit("quantum-bank-mobile missing default scopes: " + ", ".join(missing))

preferred_username_mapper = next((m for m in mobile.get("protocolMappers", [])
    if m.get("protocolMapper") == "oidc-usermodel-property-mapper"
    and m.get("config", {}).get("claim.name") == "preferred_username"
    and m.get("config", {}).get("access.token.claim") == "true"), None)
if preferred_username_mapper is None:
    sys.exit("quantum-bank-mobile must map preferred_username into access tokens")

test_client = next((c for c in clients if c.get("clientId") == "quantum-bank-test"), None)
if test_client is None:
    sys.exit("missing quantum-bank-test client")
if test_client.get("publicClient") is not False:
    sys.exit("quantum-bank-test must remain confidential")

if realm.get("sslRequired") != "all":
    sys.exit("realm must require TLS for every request (sslRequired=all)")
if realm.get("bruteForceProtected") is not True:
    sys.exit("realm must enable brute-force protection")

basic_scope = next((s for s in realm["clientScopes"] if s.get("name") == "basic"), None)
if basic_scope is None:
    sys.exit("missing basic client scope (sub claim)")
for client in clients:
    if "basic" not in client["defaultClientScopes"]:
        sys.exit(f"{client['clientId']} must include the basic scope so tokens carry sub")
    if client.get("publicClient") is False and not client.get("secret", "").startswith("${"):
        sys.exit(f"{client['clientId']} must take its secret from the environment, not the tracked realm file")
if "+" in mobile.get("webOrigins", []):
    sys.exit("quantum-bank-mobile must not allow wildcard web origins")
if mobile.get("attributes", {}).get("post.logout.redirect.uris") == "+":
    sys.exit("quantum-bank-mobile must not allow wildcard post-logout redirects")
PY

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
