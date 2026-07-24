#!/bin/sh
set -eu

terraform_cli="${TF_CLI:-terraform}"

if ! command -v "${terraform_cli}" >/dev/null 2>&1; then
  echo "ERROR: Terraform/OpenTofu executable '${terraform_cli}' was not found in PATH." >&2
  echo "Set TF_CLI to an executable installed in the development image." >&2
  exit 127
fi

exec "${terraform_cli}" "$@"
