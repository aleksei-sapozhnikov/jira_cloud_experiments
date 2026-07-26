variable "project" {
  description = "Company-managed Jira space whose workflows receive Resolution actions"

  type = object({
    id         = string
    key        = string
    management = string
  })

  nullable = false

  validation {
    condition = (
      length(trimspace(var.project.id)) > 0 &&
      length(trimspace(var.project.key)) > 0 &&
      var.project.management == "company"
    )

    error_message = "project must identify a company-managed Jira space."
  }
}

variable "issue_type_ids" {
  description = "Work type IDs used to discover every workflow in the Jira space"
  type        = set(string)
  nullable    = false

  validation {
    condition = (
      length(var.issue_type_ids) > 0 &&
      alltrue([
        for issue_type_id in var.issue_type_ids :
        length(trimspace(issue_type_id)) > 0
      ])
    )

    error_message = "issue_type_ids must contain at least one non-empty ID."
  }
}

variable "resolution_name" {
  description = "Jira Resolution assigned by transitions into a Done status"
  type        = string
  default     = "Done"
  nullable    = false

  validation {
    condition     = length(trimspace(var.resolution_name)) > 0
    error_message = "resolution_name must not be empty."
  }
}

variable "reconciliation_mode" {
  description = "Controls when the module reconciles workflow Resolution actions"
  type        = string
  default     = "on_terraform_change"

  validation {
    condition = contains(
      ["on_terraform_change", "always"],
      var.reconciliation_mode
    )

    error_message = "reconciliation_mode must be on_terraform_change or always."
  }
}
