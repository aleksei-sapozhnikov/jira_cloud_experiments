variable "project_key" {
  description = "Key of the Jira project that owns the form template"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.project_key)) > 0
    error_message = "project_key must not be empty."
  }
}

variable "form" {
  description = "Opinionated Jira form definition"

  type = object({
    name           = string
    language       = optional(string, "en")
    primary_locale = optional(string, "en-US")

    submit = optional(object({
      lock = optional(bool, false)
      pdf  = optional(bool, true)
    }), {})

    questions = list(object({
      id          = number
      key         = string
      type        = string
      label       = string
      description = optional(string)
      required    = optional(bool, false)
      choices     = optional(list(string), [])
    }))
  })

  nullable = false

  validation {
    condition     = length(trimspace(var.form.name)) > 0
    error_message = "form.name must not be empty."
  }

  validation {
    condition = alltrue([
      for question in var.form.questions :
      contains(
        [
          "short_text",
          "long_text",
          "paragraph",
          "radio",
          "checkboxes",
          "dropdown",
          "date",
          "number",
          "email",
          "url"
        ],
        question.type
      )
    ])

    error_message = "Each question.type must be one of the supported Jira Forms types."
  }

  validation {
    condition = (
      length(distinct([for question in var.form.questions : question.id])) ==
      length(var.form.questions)
    )

    error_message = "Each question.id must be unique within the form."
  }

  validation {
    condition = (
      length(distinct([for question in var.form.questions : question.key])) ==
      length(var.form.questions)
    )

    error_message = "Each question.key must be unique within the form."
  }

  validation {
    condition = alltrue([
      for question in var.form.questions :
      contains(["radio", "checkboxes", "dropdown"], question.type)
      ? length(question.choices) > 0
      : length(question.choices) == 0
    ])

    error_message = "Choice questions require choices; other question types must not define them."
  }
}

variable "publication" {
  description = "Jira work type used when the form creates a work item"

  type = object({
    issue_type_id      = string
    issue_type_name    = string
    submit_on_create   = optional(bool, true)
    validate_on_create = optional(bool, true)
  })

  nullable = false

  validation {
    condition     = length(trimspace(var.publication.issue_type_id)) > 0
    error_message = "The publication work type was not found in the form's Jira space. Create it in the space or correct publish.issue_type in forms.json."
  }
}
