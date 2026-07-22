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
