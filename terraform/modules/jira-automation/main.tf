locals {
  marker = "terraform-automation:${var.automation_key}"

  trigger = {
    component     = "TRIGGER"
    schemaVersion = 1
    type          = "jira.issue.event.trigger:created"
    value = {
      eventFilters = [
        "ari:cloud:jira:${var.cloud_id}:project/${var.source_project_id}"
      ]
      eventKey   = "jira:issue_created"
      issueEvent = "issue_created"
    }
    connectionId = null
    conditions = [{
      component     = "CONDITION"
      schemaVersion = 3
      type          = "jira.issue.condition"
      value = {
        selectedField = {
          type  = "ID"
          value = "issuetype"
        }
        selectedFieldType = "issuetype"
        comparison        = "EQUALS"
        compareValue = {
          type       = "ID"
          modifier   = null
          value      = var.source_issue_type.id
          multiValue = false
          source     = null
        }
      }
      connectionId      = null
      conditions        = []
      parentId          = null
      conditionParentId = null
      children          = []
    }]
  }

  components = [{
    component     = "ACTION"
    schemaVersion = 12
    type          = "jira.issue.create"
    value = {
      operations = [
        {
          field     = { type = "ID", value = "summary" }
          fieldType = "summary"
          type      = "SET"
          value     = "{{triggerIssue.summary}}"
        },
        {
          field     = { type = "ID", value = "description" }
          fieldType = "description"
          type      = "SET"
          value     = "Created from {{triggerIssue.key}} by Terraform-managed Jira Automation."
        },
        {
          field     = { type = "ID", value = "project" }
          fieldType = "project"
          type      = "SET"
          value     = { type = "ID", value = var.target_project.id }
        },
        {
          field     = { type = "ID", value = "issuetype" }
          fieldType = "issuetype"
          type      = "SET"
          value     = { type = "ID", value = var.target_issue_type.id }
        },
        {
          field     = { type = "ID", value = "issuelinks" }
          fieldType = "issuelinks"
          type      = "SET"
          value = {
            issue    = { type = "COPY", value = "trigger" }
            linkType = "${var.link.direction}:${var.link.id}"
          }
        }
      ]
      advancedFields    = jsonencode({ fields = {} })
      sendNotifications = var.send_notifications
    }
    connectionId = null
    conditions   = []
    children     = []
  }]

  rule = {
    marker            = local.marker
    cloud_id          = var.cloud_id
    name              = var.name
    enabled           = var.enabled
    source_project_id = var.source_project_id
    trigger           = local.trigger
    components        = local.components
  }
}

resource "terraform_data" "reconciliation" {
  input = local.rule

  triggers_replace = sha256(jsonencode(local.rule))

  provisioner "local-exec" {
    command = join(" ", [
      "node",
      "${path.module}/scripts/reconcile-jira-automation.mjs",
      "upsert",
      base64encode(jsonencode(self.input))
    ])

    interpreter = ["/bin/bash", "-c"]
  }

  lifecycle {
    precondition {
      condition     = length(trimspace(var.source_issue_type.id)) > 0
      error_message = "Source work type \"${var.source_issue_type.name}\" was not found."
    }

    precondition {
      condition     = length(trimspace(var.target_issue_type.id)) > 0
      error_message = "Target work type \"${var.target_issue_type.name}\" was not found in Jira space \"${var.target_project.key}\"."
    }
  }
}

resource "terraform_data" "cleanup" {
  input = {
    marker   = local.marker
    cloud_id = var.cloud_id
  }

  depends_on = [
    terraform_data.reconciliation
  ]

  provisioner "local-exec" {
    when = destroy

    command = join(" ", [
      "node",
      "${path.module}/scripts/reconcile-jira-automation.mjs",
      "delete",
      base64encode(jsonencode(self.input))
    ])

    interpreter = ["/bin/bash", "-c"]
  }
}
