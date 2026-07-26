output "configuration" {
  description = "Desired workflow Resolution reconciliation configuration"
  value = merge(local.desired_configuration, {
    reconciliation_mode = var.reconciliation_mode
  })
}
