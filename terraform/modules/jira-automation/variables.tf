variable "automation_key" {
  description = "Stable Terraform identity used to find the Automation rule"
  type        = string
  nullable    = false
}

variable "name" {
  description = "Display name of the Jira Automation rule"
  type        = string
  nullable    = false
}

variable "enabled" {
  description = "Whether the Jira Automation rule is enabled"
  type        = bool
  default     = true
  nullable    = false
}

variable "cloud_id" {
  description = "Atlassian Cloud ID used in Automation ARIs"
  type        = string
  nullable    = false
}

variable "source_project_id" {
  description = "Numeric ID of the Jira space that triggers the rule"
  type        = string
  nullable    = false
}

variable "source_issue_type" {
  description = "Work type that triggers the rule"
  type = object({
    id   = string
    name = string
  })
  nullable = false
}

variable "target_project" {
  description = "Jira space in which Automation creates the linked work item"
  type = object({
    id  = string
    key = string
  })
  nullable = false
}

variable "target_issue_type" {
  description = "Work type created by Automation"
  type = object({
    id   = string
    name = string
  })
  nullable = false
}

variable "link" {
  description = "Jira work-item link used between the request and created work item"
  type = object({
    id        = string
    name      = string
    direction = string
  })
  nullable = false

  validation {
    condition     = contains(["inward", "outward"], var.link.direction)
    error_message = "link.direction must be either inward or outward."
  }
}

variable "send_notifications" {
  description = "Whether the create action sends Jira notifications"
  type        = bool
  default     = false
  nullable    = false
}
