#!/bin/sh
set -eu

export TF_CLI="${TF_CLI:-terraform}"
export FORGE_USAGE_ANALYTICS="${FORGE_USAGE_ANALYTICS:-false}"

# Forge requires an explicit analytics preference before any command can use
# --non-interactive. Disposable containers do not retain the CLI setting, so
# reconcile it from the environment whenever a container starts.
forge settings set usage-analytics "${FORGE_USAGE_ANALYTICS}" >/dev/null

# The Jira provider reads ATLASSIAN_* directly, while the generic REST
# provider receives credentials through Terraform input variables. Reuse the
# same credentials without duplicating secrets in the Docker env file.
if [ -n "${ATLASSIAN_EMAIL:-}" ] &&
  [ -z "${TF_VAR_jira_forms_email:-}" ]; then
  export TF_VAR_jira_forms_email="${ATLASSIAN_EMAIL}"
fi

if [ -n "${ATLASSIAN_API_TOKEN:-}" ] &&
  [ -z "${TF_VAR_jira_forms_api_token:-}" ]; then
  export TF_VAR_jira_forms_api_token="${ATLASSIAN_API_TOKEN}"
fi

if [ -n "${ATLASSIAN_URL:-}" ] &&
  [ -z "${TF_VAR_jira_url:-}" ]; then
  export TF_VAR_jira_url="${ATLASSIAN_URL}"
fi

if [ -t 1 ]; then
  printf '%s\n' \
    '+------------------------------------------------------------------+' \
    '| Development container ready.                                     |'
  printf '| %-64s |\n' \
    "Use the tf alias for Terraform/OpenTofu (engine: ${TF_CLI})."
  printf '%s\n' \
    '+------------------------------------------------------------------+' \
    ''
fi

exec "$@"
