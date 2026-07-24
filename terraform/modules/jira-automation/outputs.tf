output "id" {
  description = "Stable Terraform identity of the Jira Automation rule"
  value       = var.automation_key
}

output "name" {
  description = "Display name of the Jira Automation rule"
  value       = var.name
}

output "enabled" {
  description = "Whether the Jira Automation rule is enabled"
  value       = var.enabled
}
