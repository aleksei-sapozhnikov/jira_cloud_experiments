moved {
  from = terraform_data.jira_configuration_profile_assignment["terraform-classic"]
  to   = module.jira_profile_assignment["terraform-classic"].terraform_data.assignment
}
