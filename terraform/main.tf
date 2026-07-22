terraform {
  required_version = ">= 1.5.0"

  required_providers {
    atlassian = {
      source  = "gothub97/atlassian"
      version = "= 0.4.0"
    }
  }
}

provider "atlassian" {
  # Credentials are read from:
  # ATLASSIAN_URL
  # ATLASSIAN_EMAIL
  # ATLASSIAN_API_TOKEN
}

locals {
  config_directory = "${path.module}/config"

  spaces = jsondecode(
    file("${local.config_directory}/spaces.json")
  )

  configuration_profiles = jsondecode(
    file("${local.config_directory}/configuration-profiles.json")
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

resource "terraform_data" "jira_configuration_profile_assignment" {
  for_each = local.jira_profile_assignments

  /*
   * Keep the desired association and execution mode visible in Terraform
   * state and outputs. The script path documents the REST-backed part of
   * the configuration explicitly.
   */
  input = merge(each.value, {
    reconciliation_mode   = var.jira_profile_reconciliation_mode
    reconciliation_script = "scripts/assign-jira-profile.mjs"
  })

  /*
   * on_change:
   *   Run only when the desired project/scheme IDs or the script change.
   *   Subsequent plans can show "No changes".
   *
   * always:
   *   plantimestamp() changes for every new plan, so apply replaces this
   *   terraform_data resource and runs the idempotent reconciliation script.
   */
  triggers_replace = {
    desired_configuration = each.value
    reconciliation_run = (
      var.jira_profile_reconciliation_mode == "always"
      ? plantimestamp()
      : "on-change-only"
    )
    script_sha256 = filesha256(
      "${path.module}/scripts/assign-jira-profile.mjs"
    )
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "node scripts/assign-jira-profile.mjs"

    environment = {
      JIRA_PROJECT_ID  = each.value.project_id
      JIRA_PROJECT_KEY = each.value.project_key

      JIRA_WORKFLOW_SCHEME_ID = (
        each.value.workflow_scheme_id
      )

      JIRA_ISSUE_TYPE_SCREEN_SCHEME_ID = (
        each.value.issue_type_screen_scheme_id
      )

      JIRA_FIELD_CONFIGURATION_SCHEME_ID = (
        each.value.field_configuration_scheme_id
      )
    }
  }
}
