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

provider "restapi" {
  alias = "jira"
  uri   = trimsuffix(var.jira_url, "/")

  username = var.jira_forms_email
  password = var.jira_forms_api_token

  headers = {
    Accept       = "application/json"
    Content-Type = "application/json"
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

  automations = jsondecode(
    file("${local.config_directory}/automations.json")
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

data "atlassian_jira_issue_types" "form_project" {
  for_each = local.forms

  project_id = module.jira_space[each.value.space].id
}

data "atlassian_jira_issue_types" "workflow_resolution" {
  for_each = {
    for space_name, space in local.spaces :
    space_name => space
    if space.management == "company"
  }

  project_id = module.jira_space[each.key].id
}

data "restapi_object" "form_service_desk" {
  provider = restapi.jira
  for_each = local.forms

  path         = "/rest/servicedeskapi/servicedesk"
  results_key  = "values"
  search_key   = "projectKey"
  search_value = module.jira_space[each.value.space].key
}

data "restapi_object" "form_request_type" {
  provider = restapi.jira
  for_each = local.forms

  path = format(
    "/rest/servicedeskapi/servicedesk/%s/requesttype",
    data.restapi_object.form_service_desk[each.key].id
  )
  results_key  = "values"
  search_key   = "name"
  search_value = each.value.publish.request_type
}

locals {
  form_issue_type_matches = {
    for form_key, form in local.forms :
    form_key => [
      for issue_type
      in data.atlassian_jira_issue_types.form_project[form_key].issue_types :
      issue_type
      if lower(issue_type.name) == lower(form.publish.issue_type)
    ]
  }

  form_issue_type_ids = {
    for form_key, issue_types in local.form_issue_type_matches :
    form_key => length(issue_types) == 1 ? issue_types[0].id : ""
  }
}

module "jira_form" {
  source = "./modules/jira-form"

  for_each = local.forms

  project_key = module.jira_space[each.value.space].key
  form        = each.value.form
  publication = {
    issue_type_id     = local.form_issue_type_ids[each.key]
    issue_type_name   = each.value.publish.issue_type
    request_type_id   = data.restapi_object.form_request_type[each.key].id
    request_type_name = each.value.publish.request_type
    portal            = try(each.value.publish.portal, false)
    submit_on_create  = try(each.value.publish.submit_on_create, true)
    validate_on_create = try(
      each.value.publish.validate_on_create,
      true
    )
  }
}

data "atlassian_jira_issue_types" "automation_source" {
  for_each = local.automations

  project_id = module.jira_space[each.value.source.space].id
}

data "atlassian_jira_issue_types" "automation_target" {
  for_each = local.automations

  project_id = module.jira_space[each.value.target.space].id
}

data "restapi_object" "automation_link_type" {
  provider = restapi.jira
  for_each = local.automations

  path         = "/rest/api/3/issueLinkType"
  results_key  = "issueLinkTypes"
  search_key   = "name"
  search_value = each.value.link.type
}

locals {
  automation_target_issue_type_matches = {
    for automation_key, automation in local.automations :
    automation_key => [
      for issue_type
      in data.atlassian_jira_issue_types.automation_target[automation_key].issue_types :
      issue_type
      if lower(issue_type.name) == lower(automation.target.issue_type)
    ]
  }

  automation_target_issue_type_ids = {
    for automation_key, issue_types
    in local.automation_target_issue_type_matches :
    automation_key => length(issue_types) == 1 ? issue_types[0].id : ""
  }

  automation_source_issue_type_ids = {
    for automation_key, automation in local.automations :
    automation_key => length([
      for issue_type
      in data.atlassian_jira_issue_types.automation_source[automation_key].issue_types :
      issue_type.id
      if lower(issue_type.name) == lower(automation.source.issue_type)
      ]) == 1 ? one([
      for issue_type
      in data.atlassian_jira_issue_types.automation_source[automation_key].issue_types :
      issue_type.id
      if lower(issue_type.name) == lower(automation.source.issue_type)
    ]) : ""
  }
}

module "jira_automation" {
  source = "./modules/jira-automation"

  for_each = local.automations

  automation_key = each.key
  kind           = try(each.value.kind, "create_linked_work_item")
  name           = each.value.name
  enabled        = try(each.value.enabled, true)
  allow_other_rule_triggers = try(
    each.value.allow_other_rule_triggers,
    false
  )
  cloud_id          = var.jira_cloud_id
  source_project_id = module.jira_space[each.value.source.space].id
  source_issue_type = {
    id   = local.automation_source_issue_type_ids[each.key]
    name = each.value.source.issue_type
  }
  target_project = {
    id  = module.jira_space[each.value.target.space].id
    key = module.jira_space[each.value.target.space].key
  }
  target_issue_type = {
    id   = local.automation_target_issue_type_ids[each.key]
    name = each.value.target.issue_type
  }
  link = {
    id        = data.restapi_object.automation_link_type[each.key].id
    name      = each.value.link.type
    direction = each.value.link.direction
  }
  incident = try({
    labels = each.value.incident.labels
  }, null)
  rca                = try(each.value.rca, null)
  send_notifications = try(each.value.send_notifications, false)
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

module "jira_workflow_resolution" {
  source = "./modules/jira-workflow-resolution"

  for_each = {
    for space_name, space in local.spaces :
    space_name => space
    if space.management == "company"
  }

  project = {
    id         = module.jira_space[each.key].id
    key        = module.jira_space[each.key].key
    management = each.value.management
  }

  issue_type_ids = toset([
    for issue_type
    in data.atlassian_jira_issue_types.workflow_resolution[each.key].issue_types :
    issue_type.id
  ])

  resolution_name     = var.jira_done_resolution_name
  reconciliation_mode = var.jira_workflow_reconciliation_mode

  depends_on = [
    module.jira_profile_assignment
  ]
}
