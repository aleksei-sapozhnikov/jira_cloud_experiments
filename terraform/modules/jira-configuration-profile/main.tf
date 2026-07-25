locals {
  /*
   * The current JSON contains a simple ordered list of status names.
   *
   * The module interprets:
   * - the first status as TODO;
   * - the last status as DONE;
   * - statuses in between as IN_PROGRESS.
   */
  workflow_statuses = [
    for index, status_name in var.profile.workflow.statuses : {
      name      = status_name
      reference = "status_${index}"

      category = (
        index == 0
        ? "TODO"
        : index == length(var.profile.workflow.statuses) - 1
        ? "DONE"
        : "IN_PROGRESS"
      )
    }
  ]

  /*
   * Generate:
   * - one initial transition;
   * - forward transitions between adjacent statuses;
   * - backward transitions between adjacent statuses.
   */
  initial_transition = {
    name                  = "Create"
    type                  = "initial"
    from_status_reference = null
    to_status_reference   = local.workflow_statuses[0].reference
  }

  forward_transitions = [
    for index in range(length(local.workflow_statuses) - 1) : {
      name = "Move to ${local.workflow_statuses[index + 1].name}"
      type = "directed"

      from_status_reference = local.workflow_statuses[index].reference
      to_status_reference   = local.workflow_statuses[index + 1].reference
    }
  ]

  backward_transitions = [
    for index in range(length(local.workflow_statuses) - 1) : {
      name = "Return to ${local.workflow_statuses[index].name}"
      type = "directed"

      from_status_reference = local.workflow_statuses[index + 1].reference
      to_status_reference   = local.workflow_statuses[index].reference
    }
  ]

  workflow_transitions = concat(
    [local.initial_transition],
    local.forward_transitions,
    local.backward_transitions
  )

  screen_definitions = {
    create = var.profile.screens.create
    edit   = var.profile.screens.edit
    view   = var.profile.screens.view
  }

  field_ids = sort(
    distinct(
      concat(
        var.profile.field_configuration.required_fields,
        var.profile.field_configuration.hidden_fields
      )
    )
  )

  /*
   * The provider uses Jira API holder type names such as projectRole,
   * while the JSON uses more readable snake_case names.
   */
  permission_holder_type_aliases = {
    project_role = "projectRole"
    project_lead = "projectLead"
    current_user = "currentUser"
  }

  permission_grants = [
    for grant in var.profile.permission_scheme.grants : {
      permission = grant.permission

      holder_type = lookup(
        local.permission_holder_type_aliases,
        grant.holder_type,
        grant.holder_type
      )

      holder_value = try(grant.holder_value, null)
    }
  ]
}

resource "atlassian_jira_workflow" "this" {
  name        = var.profile.workflow.name
  description = try(var.profile.workflow.description, null)

  /*
   * Jira returns transition extensions installed by apps such as ScriptRunner
   * inside the same transition blocks that the provider manages. Reconciling
   * those blocks would remove rules that this provider cannot declare and can
   * also misidentify transitions when Jira returns them in another order.
   *
   * Terraform still creates transitions for a new workflow. Existing
   * transitions and their app-owned rules are preserved after that.
   */
  lifecycle {
    ignore_changes = [transition]
  }

  dynamic "status" {
    for_each = local.workflow_statuses

    content {
      name             = status.value.name
      status_reference = status.value.reference
      status_category  = status.value.category
    }
  }

  dynamic "transition" {
    for_each = local.workflow_transitions

    content {
      name                  = transition.value.name
      type                  = transition.value.type
      from_status_reference = transition.value.from_status_reference
      to_status_reference   = transition.value.to_status_reference
    }
  }
}

resource "atlassian_jira_workflow_scheme" "this" {
  name        = "${var.profile.workflow.name} Scheme"
  description = try(var.profile.workflow.description, null)

  /*
   * The workflow is used for every issue type unless explicit mappings
   * are added later.
   */
  default_workflow = atlassian_jira_workflow.this.name
}

resource "atlassian_jira_screen" "this" {
  for_each = local.screen_definitions

  name        = each.value.name
  description = try(var.profile.screens.description, null)

  tab {
    name   = "Default"
    fields = each.value.fields
  }
}

resource "atlassian_jira_screen_scheme" "this" {
  name        = var.profile.screens.name
  description = try(var.profile.screens.description, null)

  default_screen_id = atlassian_jira_screen.this["view"].id
  create_screen_id  = atlassian_jira_screen.this["create"].id
  edit_screen_id    = atlassian_jira_screen.this["edit"].id
  view_screen_id    = atlassian_jira_screen.this["view"].id
}

resource "atlassian_jira_issue_type_screen_scheme" "this" {
  name        = "${var.profile.screens.name} Issue Types"
  description = try(var.profile.screens.description, null)

  mapping {
    issue_type_id    = "default"
    screen_scheme_id = atlassian_jira_screen_scheme.this.id
  }
}

resource "atlassian_jira_field_configuration" "this" {
  name        = var.profile.field_configuration.name
  description = try(var.profile.field_configuration.description, null)

  dynamic "field_item" {
    for_each = local.field_ids

    content {
      field_id = field_item.value

      is_required = contains(
        var.profile.field_configuration.required_fields,
        field_item.value
      )

      is_hidden = contains(
        var.profile.field_configuration.hidden_fields,
        field_item.value
      )
    }
  }
}

resource "atlassian_jira_field_configuration_scheme" "this" {
  name        = "${var.profile.field_configuration.name} Scheme"
  description = try(var.profile.field_configuration.description, null)

  mapping {
    issue_type_id          = "default"
    field_configuration_id = atlassian_jira_field_configuration.this.id
  }
}

resource "atlassian_jira_permission_scheme" "this" {
  count = try(var.profile.permission_scheme.enabled, true) ? 1 : 0

  name        = var.profile.permission_scheme.name
  description = try(var.profile.permission_scheme.description, null)

  dynamic "permission" {
    for_each = local.permission_grants

    content {
      permission   = permission.value.permission
      holder_type  = permission.value.holder_type
      holder_value = permission.value.holder_value
    }
  }
}
