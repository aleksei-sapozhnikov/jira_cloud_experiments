#!/bin/sh
set -eu

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

exec "$@"
