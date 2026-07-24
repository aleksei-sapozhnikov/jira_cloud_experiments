output "id" {
  description = "Jira form template ID"
  value       = restapi_object.form.id
}

output "name" {
  description = "Jira form template name"
  value       = var.form.name
}

output "project_key" {
  description = "Key of the Jira project that owns the form template"
  value       = var.project_key
}

output "issue_type_id" {
  description = "ID of the Jira work type used when the form is submitted"
  value       = var.publication.issue_type_id
}

output "issue_type_name" {
  description = "Name of the Jira work type used when the form is submitted"
  value       = var.publication.issue_type_name
}
