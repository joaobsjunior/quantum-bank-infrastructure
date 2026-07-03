#!/usr/bin/env bash
set -euo pipefail

# CI validation gate for the infrastructure layer (test-coverage-enforcement
# capability, config/script equivalent). Aggregates the self-contained static
# config checks: terraform fmt/validate for aws/gcp/azure and the Keycloak config
# verification. Cross-layer checks (verify-local-e2e-config.sh, which inspects
# sibling submodules) and runtime smoke (local-e2e-smoke.sh) are excluded here;
# they need the assembled superproject and run in its opt-in e2e job.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

checks=(
  "verify-terraform-config.sh"
  "verify-keycloak-config.sh"
)

for check in "${checks[@]}"; do
  check_path="${script_dir}/${check}"
  if [[ ! -x "${check_path}" && ! -f "${check_path}" ]]; then
    echo "missing infrastructure check: ${check_path}" >&2
    exit 1
  fi
  echo "running ${check}"
  bash "${check_path}"
done

echo "infrastructure-validate-ok"
