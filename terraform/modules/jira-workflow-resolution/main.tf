locals {
  desired_configuration = {
    project_id      = var.project.id
    project_key     = var.project.key
    issue_type_ids  = sort(tolist(var.issue_type_ids))
    resolution_name = var.resolution_name
  }
}

resource "terraform_data" "reconciliation" {
  input = merge(local.desired_configuration, {
    reconciliation_mode = var.reconciliation_mode
  })

  triggers_replace = {
    desired_configuration = local.desired_configuration
    reconciliation_run = (
      var.reconciliation_mode == "always"
      ? plantimestamp()
      : "on-change-only"
    )
    script_sha256 = filesha256(
      "${path.module}/scripts/reconcile-workflow-resolution.mjs"
    )
  }

  provisioner "local-exec" {
    working_dir = path.module
    command = join(" ", [
      "node",
      "scripts/reconcile-workflow-resolution.mjs",
      "apply",
      base64encode(jsonencode(local.desired_configuration))
    ])

    interpreter = ["/bin/bash", "-c"]
  }
}
