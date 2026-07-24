variable "jira_profile_reconciliation_mode" {
  description = "Controls when Jira project-to-scheme associations are reconciled"
  type        = string
  default     = "on_change"

  validation {
    condition = contains(
      ["on_change", "always"],
      var.jira_profile_reconciliation_mode
    )

    error_message = "jira_profile_reconciliation_mode must be on_change or always."
  }
}

variable "jira_project_lead_account_id" {
  description = "Jira account ID assigned as the lead of spaces created by Terraform"
  type        = string
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.jira_project_lead_account_id)) > 0 &&
      var.jira_project_lead_account_id != "replace-with-jira-account-id"
    )

    error_message = "jira_project_lead_account_id must contain a real Jira account ID."
  }
}

variable "jira_cloud_id" {
  description = "Cloud ID of the Jira site used in Atlassian OAuth API URLs"
  type        = string
  nullable    = false

  validation {
    condition = can(
      regex(
        "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
        var.jira_cloud_id
      )
    )

    error_message = "jira_cloud_id must be a UUID."
  }
}

variable "jira_forms_oauth_access_token" {
  description = "Short-lived Atlassian OAuth 2.0 (3LO) access token used by the Jira Forms API"
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.jira_forms_oauth_access_token)) > 0 &&
      var.jira_forms_oauth_access_token != "replace-with-oauth-access-token"
    )

    error_message = "jira_forms_oauth_access_token must contain a current OAuth 2.0 (3LO) access token."
  }
}
