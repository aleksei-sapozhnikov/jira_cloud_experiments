locals {
  desired_assignment = {
    project_id            = var.project.id
    project_key           = var.project.key
    configuration_profile = var.profile_key

    workflow_scheme_id            = var.schemes.workflow_id
    issue_type_screen_scheme_id   = var.schemes.issue_type_screen_id
    field_configuration_scheme_id = var.schemes.field_configuration_id
  }
}

resource "terraform_data" "assignment" {
  input = merge(local.desired_assignment, {
    reconciliation_mode = var.reconciliation_mode
  })

  /*
   * on_change:
   *   Run only when desired IDs or this module's helper script change.
   *
   * always:
   *   plantimestamp() changes for every plan, so apply replaces this
   *   terraform_data resource and runs the idempotent reconciliation.
   */
  triggers_replace = {
    desired_configuration = local.desired_assignment
    reconciliation_run = (
      var.reconciliation_mode == "always"
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
      JIRA_PROJECT_ID  = var.project.id
      JIRA_PROJECT_KEY = var.project.key

      JIRA_WORKFLOW_SCHEME_ID = (
        var.schemes.workflow_id
      )

      JIRA_ISSUE_TYPE_SCREEN_SCHEME_ID = (
        var.schemes.issue_type_screen_id
      )

      JIRA_FIELD_CONFIGURATION_SCHEME_ID = (
        var.schemes.field_configuration_id
      )
    }
  }
}
