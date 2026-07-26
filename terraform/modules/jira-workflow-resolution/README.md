# Jira workflow Resolution

This module keeps Jira work item Resolution values consistent with workflow
status categories in company-managed Jira spaces.

It applies the same rule to every workflow used by a supplied company-managed
space:

- a transition into a status in the `Done` category sets Resolution to the
  configured value (`Done` by default);
- a transition from `Done` to any other status category clears Resolution;
- other transitions are left unchanged.

The rule uses status categories rather than status or transition names, so it
works for spaces whose workflows use names such as `Complete`, `Resolve`,
`Reopen`, or `Investigate`.

## How category-based reconciliation works

The module does not assign or change status categories. Jira already associates
every status with a system category such as `TODO`, `IN_PROGRESS`, or `DONE`.

At reconciliation time, the module requests the current workflows and statuses
from Jira's REST API. The response supplies each status reference and its
category. The module then examines the source and destination of every
transition:

```text
In Progress [IN_PROGRESS] --Complete--> Done [DONE]
Done [DONE] --Reopen--> In Progress [IN_PROGRESS]
```

The native Resolution action belongs to the transition, not to either status.
The first transition therefore receives `Resolution = Done`, while the second
receives an action that clears Resolution. If several transitions lead into the
`DONE` category, each receives the setting action.

A global transition to a non-Done category also clears Resolution because Jira
can invoke it from a Done status. Initial transitions and transitions that stay
within the same non-Done category do not need a Resolution action.

This discovery happens during module execution. The root Terraform
configuration does not need to know workflow names, transition names, status
IDs, or categories in advance.

Team-managed spaces are deliberately outside this module. Jira rejects
Resolution as an unsupported field in their workflow `Update field` rules.
Atlassian recommends Jira Automation when an explicit Resolution value is
required there; that is a separate lifecycle with Automation execution costs.

## Why this is a separate module

The Atlassian Terraform provider manages a transition as one complete object.
Updating its post-functions that way could also overwrite ScriptRunner
validators or other rules added outside Terraform.

This module therefore uses Jira's workflow REST API internally. It reads the
workflows used by the supplied space, changes only the native Resolution
post-function, validates the complete update with Jira, and then applies it.
Other transition rules are preserved.

The root configuration only supplies a space, its work types, and the desired
Resolution. The REST implementation is private to the module.

## Usage

```hcl
module "workflow_resolution" {
  source = "./modules/jira-workflow-resolution"

  project = {
    id         = module.jira_space.id
    key        = module.jira_space.key
    management = "company"
  }

  issue_type_ids     = data.atlassian_jira_issue_types.space.issue_types[*].id
  resolution_name    = "Done"
  reconciliation_mode = "on_terraform_change"
}
```

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `project` | ID, key, and `company` management type of the Jira space whose workflows are reconciled. | Required |
| `issue_type_ids` | Work type IDs used to discover all workflows assigned in the space. | Required |
| `resolution_name` | Resolution set by transitions into the `Done` category. | `Done` |
| `reconciliation_mode` | Reconcile when Terraform inputs or the script change, or on every plan/apply cycle. | `on_terraform_change` |

`reconciliation_mode` accepts:

- `on_terraform_change` — run after the module configuration or implementation
  changes;
- `always` — schedule reconciliation on every Terraform plan and apply cycle.

## Environment

The module runs inside the repository development container and uses the Jira
credentials already required by the root Terraform configuration:

- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

## Lifecycle boundary

Terraform owns the presence and parameters of the native Resolution actions.
Jira or installed apps may continue to own all other transition rules. Removing
this module from the Terraform configuration does not remove actions that were
previously applied.
