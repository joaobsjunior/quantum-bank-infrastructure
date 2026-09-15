#!/bin/sh
set -eu

token_url="${KEYCLOAK_TOKEN_URL:-https://keycloak:8443/realms/quantum-bank-local/protocol/openid-connect/token}"
client_id="${KEYCLOAK_TEST_CLIENT_ID:-quantum-bank-test}"
client_secret="${KEYCLOAK_TEST_CLIENT_SECRET:?KEYCLOAK_TEST_CLIENT_SECRET is required}"
smoke_username="${KEYCLOAK_SMOKE_USERNAME:-alice@quantumbank.local}"
smoke_password="${KEYCLOAK_SMOKE_PASSWORD:?KEYCLOAK_SMOKE_PASSWORD is required}"
smoke_subject="${KEYCLOAK_SMOKE_SUBJECT:-00000000-0000-0000-0000-000000000001}"
bootstrap_url="${GATEWAY_BOOTSTRAP_URL:-https://gateway-bootstrap:8080}"
banking_url="${GATEWAY_BANKING_URL:-https://gateway-banking:8443}"
backend_direct_url="${BACKEND_DIRECT_URL:-https://backend:8080}"
trust_anchor="${TRUST_ANCHOR:-/etc/quantum-bank/runtime/root-ca.crt}"
client_cert="${MOBILE_CLIENT_CERT:-/etc/quantum-bank/runtime/mobile-smoke-client.crt}"
client_key="${MOBILE_CLIENT_KEY:-/etc/quantum-bank/runtime/mobile-smoke-client.key}"
enroll_csr="${MOBILE_ENROLL_CSR:-/etc/quantum-bank/runtime/mobile-smoke-enroll.csr}"
body_file="/tmp/quantum-bank-smoke-body"

fail() {
  echo "local e2e smoke failed: $*" >&2
  if [ -f "${body_file}" ]; then
    cat "${body_file}" >&2 || true
  fi
  exit 1
}

# Every call to the issuer verifies the PKI-issued server certificate; there is
# no plaintext or "insecure" path anywhere in this script.
wait_for_token() {
  attempts=0
  response=""
  while [ "${attempts}" -lt 60 ]; do
    attempts=$((attempts + 1))
    response="$(curl -fsS \
      --cacert "${trust_anchor}" \
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

expect_body_not_contains() {
  unexpected="$1"
  if grep -Fq "${unexpected}" "${body_file}"; then
    fail "expected response body not to contain '${unexpected}'"
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

  # Only a TLS-layer rejection counts; a missing local file, DNS failure or
  # timeout must not pass the negative case.
  case "${output}" in
    *"could not load"*|*"Could not resolve"*|*"timed out"*)
      echo "${output}" > "${body_file}"
      fail "${name} failed for a non-TLS reason"
      ;;
    *handshake*|*alert*|*"certificate required"*|*"certificate verify"*|*"unknown ca"*|*"bad certificate"*|*"SSL routines"*|*"OpenSSL SSL_"*)
      return 0
      ;;
    *)
      echo "${output}" > "${body_file}"
      fail "${name} failed for a non-TLS reason"
      ;;
  esac
}

json_escape_file() {
  # Turns a multi-line PEM file into a single JSON string value.
  awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print $0 "\\n" }' "$1"
}

for fixture in "${trust_anchor}" "${client_cert}" "${client_key}" "${enroll_csr}"; do
  if [ ! -f "${fixture}" ]; then
    fail "missing smoke fixture ${fixture}; run pki/scripts/bootstrap-runtime-certs.sh first"
  fi
done

token="$(wait_for_token)"
wait_for_banking_ready

# The issuer must not serve plaintext HTTP anywhere: neither on its legacy
# 8080 port (must be closed) nor on the TLS port (must reject non-TLS bytes).
expect_plaintext_rejected() {
  name="$1"
  url="$2"
  set +e
  output="$(curl -sS --connect-timeout 5 --max-time 10 -d grant_type=password "${url}" 2>&1)"
  status=$?
  set -e
  case "${status}" in
    7|52|35|56)
      return 0
      ;;
  esac
  echo "${output}" > "${body_file}"
  fail "${name} was not rejected (curl exit ${status})"
}

plaintext_token_url="$(printf '%s' "${token_url}" | sed 's#^https://#http://#')"
expect_plaintext_rejected "plaintext token request to the issuer TLS port" "${plaintext_token_url}"
expect_plaintext_rejected "plaintext token request to the issuer legacy port" \
  "$(printf '%s' "${plaintext_token_url}" | sed 's#:8443/#:8080/#')"

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

# Request validation is enforced end to end (oversized amount).
expect_http_status 400 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d '{"amount":99999999999,"recipientKey":"recipient@example.com","scenario":"SUCCESS"}' \
  "${banking_url}/pix/transfers"
expect_body_contains '"errorCode":"request_invalid"'

expect_tls_failure "direct backend call without gateway client certificate" \
  --connect-timeout 5 \
  --max-time 10 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  "${backend_direct_url}/statements"

# Gateway-only guard: a valid PKI-issued certificate that is not the gateway's
# own identity is rejected by the backend even with a valid token.
expect_http_status 403 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  "${backend_direct_url}/statements"
expect_body_contains '"errorCode":"mtls_client_not_allowed"'

# Bootstrap: OTK issuance then CSR enrollment with a real CSR bound to the
# authenticated subject.
expect_http_status 202 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d '{"appInstanceId":"smoke-app","deviceId":"smoke-device","certificateProfile":"quantum-bank-mobile-client-v1"}' \
  "${bootstrap_url}/auth/otk"
expect_body_contains '"otk"'
otk="$(sed -n 's/.*"otk":"\([^"]*\)".*/\1/p' "${body_file}")"
[ -n "${otk}" ] || fail "could not extract otk"

csr_json="$(json_escape_file "${enroll_csr}")"
printf '{"otk":"%s","csr":"%s","appInstanceId":"smoke-app","deviceId":"smoke-device","certificateProfile":"quantum-bank-mobile-client-v1","environment":"local"}' \
  "${otk}" "${csr_json}" > /tmp/quantum-bank-smoke-csr.json
expect_http_status 202 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/quantum-bank-smoke-csr.json \
  "${bootstrap_url}/auth/csr"
expect_body_contains '"certificate":"-----BEGIN CERTIFICATE-----'
expect_body_not_contains 'PRIVATE KEY'

# Replaying the same OTK must fail closed.
expect_http_status 409 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/quantum-bank-smoke-csr.json \
  "${bootstrap_url}/auth/csr"
expect_body_contains '"errorCode":"otk_replayed"'

# Identifiers that could reach the OpenSSL configuration are rejected up front.
expect_http_status 400 \
  --cacert "${trust_anchor}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d '{"appInstanceId":"smoke-app","deviceId":"smoke\n[v3_client]\nbasicConstraints=CA:TRUE","certificateProfile":"quantum-bank-mobile-client-v1"}' \
  "${bootstrap_url}/auth/otk"
expect_body_contains '"errorCode":"request_invalid"'

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
expect_body_contains '"description":"Local smoke success"'

expect_http_status 200 \
  --cacert "${trust_anchor}" \
  --cert "${client_cert}" \
  --key "${client_key}" \
  -H "Authorization: Bearer ${token}" \
  "${banking_url}/profile"
expect_body_contains "\"subject\":\"${smoke_subject}\""

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
