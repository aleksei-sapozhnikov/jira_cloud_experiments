terraform {
  required_version = ">= 1.5.0"

  required_providers {
    atlassian = {
      source  = "gothub97/atlassian"
      version = "= 0.4.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "= 3.0.0"
    }
  }
}

provider "atlassian" {
  # Credentials are read from:
  # ATLASSIAN_URL
  # ATLASSIAN_EMAIL
  # ATLASSIAN_API_TOKEN
}

provider "restapi" {
  uri = "https://api.atlassian.com/jira/forms/cloud/${var.jira_cloud_id}"

  username              = var.jira_forms_email
  password              = var.jira_forms_api_token
  create_returns_object = true

  headers = {
    Accept            = "application/json"
    Content-Type      = "application/json"
    X-ExperimentalApi = "opt-in"
  }

  retries {
    max_retries = 3
    min_wait    = 1
    max_wait    = 10
  }
}

locals {
  config_directory = "${path.module}/config"

  spaces = jsondecode(
    file("${local.config_directory}/spaces.json")
  )

  configuration_profiles = jsondecode(
    file("${local.config_directory}/configuration-profiles.json")
  )

  forms = jsondecode(
    file("${local.config_directory}/forms.json")
  )

  team_managed_spaces = {
    for configuration_name, space in local.spaces :
    configuration_name => space
    if try(space.management, null) == "team"
  }

  company_managed_spaces = {
    for configuration_name, space in local.spaces :
    configuration_name => space
    if try(space.management, null) == "company"
  }

  configured_company_spaces = {
    for configuration_name, space in local.company_managed_spaces :
    configuration_name => space
    if try(space.configuration_profile, null) != null
  }

  permission_managed_company_spaces = {
    for configuration_name, space in local.configured_company_spaces :
    configuration_name => space
    if try(
      local.configuration_profiles[
        space.configuration_profile
      ].permission_scheme.enabled,
      true
    )
  }
}

module "jira_form" {
  source = "./modules/jira-form"

  for_each = local.forms

  project_key = module.jira_space[each.value.space].key
  form        = each.value.form
}

module "jira_space" {
  source = "./modules/jira-space"

  for_each = local.spaces

  key                  = each.value.key
  name                 = each.value.name
  project_type_key     = try(each.value.project_type_key, "software")
  project_template_key = each.value.project_template_key
  description          = try(each.value.description, null)
  assignee_type        = try(each.value.assignee_type, "PROJECT_LEAD")
  lead_account_id      = var.jira_project_lead_account_id
}

module "jira_configuration_profile" {
  source = "./modules/jira-configuration-profile"

  for_each = local.configuration_profiles

  profile_key = each.key
  profile     = each.value
}

resource "atlassian_jira_project_permission_scheme" "profile" {
  for_each = local.permission_managed_company_spaces

  project_key = module.jira_space[each.key].key

  scheme_id = module.jira_configuration_profile[
    each.value.configuration_profile
  ].permission_scheme_id
}

locals {
  jira_profile_assignments = {
    for space_name, space in local.configured_company_spaces :
    space_name => {
      project_id            = module.jira_space[space_name].id
      project_key           = module.jira_space[space_name].key
      configuration_profile = space.configuration_profile

      workflow_scheme_id = module.jira_configuration_profile[
        space.configuration_profile
      ].workflow_scheme_id

      issue_type_screen_scheme_id = module.jira_configuration_profile[
        space.configuration_profile
      ].issue_type_screen_scheme_id

      field_configuration_scheme_id = module.jira_configuration_profile[
        space.configuration_profile
      ].field_configuration_scheme_id
    }
  }
}

module "jira_profile_assignment" {
  source = "./modules/jira-profile-assignment"

  for_each = local.jira_profile_assignments

  project = {
    id  = each.value.project_id
    key = each.value.project_key
  }

  schemes = {
    workflow_id = each.value.workflow_scheme_id
    issue_type_screen_id = (
      each.value.issue_type_screen_scheme_id
    )
    field_configuration_id = (
      each.value.field_configuration_scheme_id
    )
  }

  profile_key         = each.value.configuration_profile
  reconciliation_mode = var.jira_profile_reconciliation_mode
}
