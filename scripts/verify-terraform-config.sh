#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
terraform_dir="${repo_dir}/terraform"

required_paths=(
  "${terraform_dir}/README.md"
  "${terraform_dir}/modules/runtime-conventions/main.tf"
  "${terraform_dir}/modules/runtime-conventions/variables.tf"
  "${terraform_dir}/modules/runtime-conventions/outputs.tf"
  "${terraform_dir}/aws/versions.tf"
  "${terraform_dir}/aws/main.tf"
  "${terraform_dir}/aws/variables.tf"
  "${terraform_dir}/aws/outputs.tf"
  "${terraform_dir}/aws/README.md"
  "${terraform_dir}/gcp/versions.tf"
  "${terraform_dir}/gcp/main.tf"
  "${terraform_dir}/gcp/variables.tf"
  "${terraform_dir}/gcp/outputs.tf"
  "${terraform_dir}/gcp/README.md"
  "${terraform_dir}/azure/versions.tf"
  "${terraform_dir}/azure/main.tf"
  "${terraform_dir}/azure/variables.tf"
  "${terraform_dir}/azure/outputs.tf"
  "${terraform_dir}/azure/README.md"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "${path}" ]]; then
    echo "missing ${path}" >&2
    exit 1
  fi
done

run_terraform() {
  if command -v terraform >/dev/null 2>&1; then
    terraform "$@"
    return
  fi

  docker run --rm \
    -v "${repo_dir}:/workspace" \
    -w /workspace \
    hashicorp/terraform:1.14.1 "$@"
}

run_terraform -chdir=terraform fmt -check -recursive

for root in aws gcp azure; do
  run_terraform -chdir="terraform/${root}" init -backend=false -input=false
  run_terraform -chdir="terraform/${root}" validate
done

echo "terraform-config-ok"
