variable "profile_key" {
  description = "Stable configuration profile identifier used by Terraform"
  type        = string

  validation {
    condition     = length(trimspace(var.profile_key)) > 0
    error_message = "profile_key must not be empty."
  }
}

variable "profile" {
  description = "Jira configuration profile loaded from JSON"

  type = object({
    workflow = object({
      key         = string
      name        = string
      description = optional(string)
      statuses    = list(string)
    })

    permission_scheme = object({
      enabled     = optional(bool, true)
      key         = string
      name        = string
      description = optional(string)

      grants = list(object({
        permission   = string
        holder_type  = string
        holder_value = optional(string)
      }))
    })

    screens = object({
      key         = string
      name        = string
      description = optional(string)

      create = object({
        name     = string
        tab_name = optional(string, "Default")
        fields   = list(string)
      })

      edit = object({
        name     = string
        tab_name = optional(string, "Default")
        fields   = list(string)
      })

      view = object({
        name     = string
        tab_name = optional(string, "Default")
        fields   = list(string)
      })
    })

    field_configuration = object({
      key             = string
      name            = string
      description     = optional(string)
      required_fields = list(string)
      hidden_fields   = list(string)
    })
  })

  validation {
    condition     = length(var.profile.workflow.statuses) >= 2
    error_message = "A workflow must contain at least two statuses."
  }

  validation {
    condition = alltrue([
      for status in var.profile.workflow.statuses :
      length(trimspace(status)) > 0
    ])

    error_message = "Workflow status names must not be empty."
  }

  validation {
    condition = alltrue([
      for screen in [
        var.profile.screens.create,
        var.profile.screens.edit,
        var.profile.screens.view
      ] :
      length(trimspace(screen.tab_name)) > 0
    ])

    error_message = "Screen tab names must not be empty."
  }

  validation {
    condition = length(
      setintersection(
        toset(var.profile.field_configuration.required_fields),
        toset(var.profile.field_configuration.hidden_fields)
      )
    ) == 0

    error_message = "A field cannot be both required and hidden."
  }
}
