output "assignment" {
  description = "Desired Jira project-to-configuration-profile assignment"
  value = merge(local.desired_assignment, {
    reconciliation_mode = var.reconciliation_mode
  })
}
