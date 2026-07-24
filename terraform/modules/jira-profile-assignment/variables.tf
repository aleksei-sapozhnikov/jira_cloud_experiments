variable "project" {
  description = "Jira project that receives the configuration profile"

  type = object({
    id  = string
    key = string
  })

  nullable = false

  validation {
    condition = (
      length(trimspace(var.project.id)) > 0 &&
      length(trimspace(var.project.key)) > 0
    )

    error_message = "project.id and project.key must not be empty."
  }
}

variable "schemes" {
  description = "Jira scheme IDs assigned to the project"

  type = object({
    workflow_id            = string
    issue_type_screen_id   = string
    field_configuration_id = string
  })

  nullable = false

  validation {
    condition = alltrue([
      for scheme_id in values(var.schemes) :
      length(trimspace(scheme_id)) > 0
    ])

    error_message = "All scheme IDs must not be empty."
  }
}

variable "profile_key" {
  description = "Stable configuration-profile key shown in module outputs"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.profile_key)) > 0
    error_message = "profile_key must not be empty."
  }
}

variable "reconciliation_mode" {
  description = "Controls when the module checks and applies Jira scheme assignments"
  type        = string
  default     = "on_change"

  validation {
    condition = contains(
      ["on_change", "always"],
      var.reconciliation_mode
    )

    error_message = "reconciliation_mode must be on_change or always."
  }
}
