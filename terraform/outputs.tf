output "jira_spaces" {
  description = "Jira spaces managed by Terraform"

  value = {
    for configuration_name, space in module.jira_space :
    configuration_name => {
      id         = space.id
      key        = space.key
      name       = space.name
      self       = space.self
      management = local.spaces[configuration_name].management
      configuration_profile = try(
        local.spaces[configuration_name].configuration_profile,
        null
      )
    }
  }
}

output "configuration_profiles" {
  description = "Configuration profiles loaded from JSON"

  value = {
    for profile_name, profile in local.configuration_profiles :
    profile_name => {
      workflow_name             = profile.workflow.name
      permission_scheme_name    = profile.permission_scheme.name
      permission_scheme_enabled = try(profile.permission_scheme.enabled, true)
      screens_name              = profile.screens.name
      field_configuration_name  = profile.field_configuration.name
    }
  }
}

output "company_spaces_by_profile" {
  description = "Company-managed spaces grouped by configuration profile"

  value = {
    for profile_name in keys(local.configuration_profiles) :
    profile_name => [
      for configuration_name, space in local.configured_company_spaces :
      configuration_name
      if space.configuration_profile == profile_name
    ]
  }
}

output "jira_configuration_profiles" {
  description = "Jira configuration profiles managed by Terraform"

  value = {
    for profile_key, profile in module.jira_configuration_profile :
    profile_key => {
      workflow_id                   = profile.workflow_id
      workflow_name                 = profile.workflow_name
      workflow_scheme_id            = profile.workflow_scheme_id
      screen_ids                    = profile.screen_ids
      screen_scheme_id              = profile.screen_scheme_id
      issue_type_screen_scheme_id   = profile.issue_type_screen_scheme_id
      field_configuration_id        = profile.field_configuration_id
      field_configuration_scheme_id = profile.field_configuration_scheme_id
      permission_scheme_id          = profile.permission_scheme_id
      permission_scheme_enabled     = profile.permission_scheme_enabled
    }
  }
}

output "jira_profile_assignments" {
  description = "Desired Jira project-to-configuration-profile associations"

  value = {
    for space_name, assignment
    in terraform_data.jira_configuration_profile_assignment :

    space_name => assignment.output
  }
}

output "jira_profile_reconciliation_mode" {
  description = "Current Jira profile association reconciliation mode"
  value       = var.jira_profile_reconciliation_mode
}
