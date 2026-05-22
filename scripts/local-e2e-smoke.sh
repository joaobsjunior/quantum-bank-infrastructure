#!/bin/sh
set -eu

token_url="${KEYCLOAK_TOKEN_URL:-http://keycloak:8080/realms/quantum-bank-local/protocol/openid-connect/token}"
client_id="${KEYCLOAK_TEST_CLIENT_ID:-quantum-bank-test}"
client_secret="${KEYCLOAK_TEST_CLIENT_SECRET:-change-me-local-only}"
smoke_username="${KEYCLOAK_SMOKE_USERNAME:-alice@quantumbank.local}"
smoke_password="${KEYCLOAK_SMOKE_PASSWORD:-change-me-local-only}"
bootstrap_url="${GATEWAY_BOOTSTRAP_URL:-https://gateway-bootstrap:8080}"
banking_url="${GATEWAY_BANKING_URL:-https://gateway-banking:8443}"
backend_direct_url="${BACKEND_DIRECT_URL:-https://backend:8080}"
trust_anchor="${TRUST_ANCHOR:-/etc/quantum-bank/runtime/root-ca.crt}"
client_cert="${MOBILE_CLIENT_CERT:-/etc/quantum-bank/runtime/mobile-smoke-client.crt}"
client_key="${MOBILE_CLIENT_KEY:-/etc/quantum-bank/runtime/mobile-smoke-client.key}"
body_file="/tmp/quantum-bank-smoke-body"

fail() {
  echo "local e2e smoke failed: $*" >&2
  if [ -f "${body_file}" ]; then
    cat "${body_file}" >&2 || true
  fi
  exit 1
}

wait_for_token() {
  attempts=0
  response=""
  while [ "${attempts}" -lt 60 ]; do
    attempts=$((attempts + 1))
    response="$(curl -fsS \
      -d grant_type=password \
      -d client_id="${client_id}" \
      -d client_secret="${client_secret}" \
      -d username="${smoke_username}" \
      -d password="${smoke_password}" \
      "${token_url}" 2>/dev/null || true)"

    token="$(printf '%s' "${response}" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"
    if [ -n "${token}" ]; then
      printf '%s' "${token}"
      return 0
    fi
    sleep 2
  done

  fail "could not obtain local Keycloak token"
}

expect_http_status() {
  expected="$1"
  shift

  status="$(curl -sS -o "${body_file}" -w '%{http_code}' "$@" || true)"
  if [ "${status}" != "${expected}" ]; then
    fail "expected HTTP ${expected}, got ${status}"
  fi
}

expect_body_contains() {
  expected="$1"
  if ! grep -Fq "${expected}" "${body_file}"; then
    fail "expected response body to contain '${expected}'"
  fi
}

wait_for_banking_ready() {
  attempts=0
  while [ "${attempts}" -lt 60 ]; do
    attempts=$((attempts + 1))
    status="$(curl -sS -o "${body_file}" -w '%{http_code}' \
      --cacert "${trust_anchor}" \
      --cert "${client_cert}" \
      --key "${client_key}" \
      -H "Authorization: Bearer ${token}" \
      "${banking_url}/statements" || true)"

    if [ "${status}" = "200" ]; then
      return 0
    fi

    sleep 2
  done

  fail "banking gateway/backend did not become ready"
}

expect_tls_failure() {
  name="$1"
  shift

  set +e
  output="$(curl -sS "$@" 2>&1)"
  status=$?
  set -e

  if [ "${status}" -eq 0 ]; then
    echo "${output}" > "${body_file}"
    fail "${name} unexpectedly succeeded"
  fi

  case "${output}" in
    *handshake*|*alert*|*certificate*|*SSL*|*ssl*|*TLS*|*tls*)
      return 0
      ;;
    *)
      echo "${output}" > "${body_file}"
      fail "${name} failed for a non-TLS reason"
      ;;
  esac
}

token="$(wait_for_token)"
wait_for_banking_ready

expect_http_status 401 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  "${banking_url}/statements"

expect_http_status 401 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer invalid-token" \
  "${banking_url}/statements"

expect_tls_failure "missing client certificate to banking gateway" \
  --connect-timeout 5 \
  --max-time 10 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  "${banking_url}/statements"

expect_http_status 200 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d '{"amount":25.30,"recipientKey":"recipient@example.com","description":"Local smoke success","scenario":"SUCCESS"}' \
  "${banking_url}/pix/transfers"
expect_body_contains '"status":"COMPLETED"'

expect_tls_failure "direct backend call without gateway client certificate" \
  --connect-timeout 5 \
  --max-time 10 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  "${backend_direct_url}/statements"

expect_http_status 422 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d '{"amount":25.30,"recipientKey":"recipient@example.com","description":"Local smoke error","scenario":"ERROR"}' \
  "${banking_url}/pix/transfers"
expect_body_contains '"errorCode":"pix_simulated_error"'

expect_http_status 200 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  "${banking_url}/statements"
expect_body_contains '"entries"'

expect_http_status 200 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  "${banking_url}/profile"
expect_body_contains '"subject":"quantum-bank-test"'

expect_http_status 200 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d '{"fullName":"Alice Quantum Smoke","email":"alice.smoke@quantumbank.local","phone":"+55 71 90000-0603","address":"Rua Smoke E2E, 603 - Salvador, BA"}' \
  "${banking_url}/profile"
expect_body_contains '"fullName":"Alice Quantum Smoke"'

expect_http_status 401 \
  --cacert "${trust_anchor}" \
  -H "Content-Type: application/json" \
  -d '{"appInstanceId":"smoke-app","deviceId":"smoke-device"}' \
  "${bootstrap_url}/auth/otk"

echo "local-e2e-smoke-ok"
