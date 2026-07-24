variable "jira_profile_reconciliation_mode" {
  description = "Controls when Jira project-to-scheme associations are reconciled"
  type        = string
  default     = "on_terraform_change"

  validation {
    condition = contains(
      ["on_terraform_change", "always"],
      var.jira_profile_reconciliation_mode
    )

    error_message = "jira_profile_reconciliation_mode must be on_terraform_change or always."
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
  description = "Cloud ID of the Jira site used in Jira Forms API URLs"
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

variable "jira_forms_email" {
  description = "Atlassian account email used for Jira Forms Basic authentication"
  type        = string
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.jira_forms_email)) > 0 &&
      var.jira_forms_email != "you@example.com"
    )

    error_message = "jira_forms_email must contain the Atlassian account email used by the Jira API token."
  }
}

variable "jira_forms_api_token" {
  description = "Atlassian API token used for Jira Forms Basic authentication"
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.jira_forms_api_token)) > 0 &&
      var.jira_forms_api_token != "replace-with-jira-api-token"
    )

    error_message = "jira_forms_api_token must contain a current Atlassian API token."
  }
}
