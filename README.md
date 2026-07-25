# Jira Cloud Incident/RCA automation experiments

This repository contains hands-on experiments with Jira Cloud administration
and automation: Terraform-managed configuration, Jira Automation flows,
ScriptRunner Cloud rules, a Forge custom app, a signed AWS webhook, and a
reproducible development container. The examples meet in a small Incident and
root-cause analysis (RCA) process but can also be reviewed independently.
[See the complete portfolio overview and reproduction paths.](OVERVIEW.md)

## What happens in Jira

A user submits the **Terraform Incident Report** through a team-managed Jira
Service Management project (`TFJSM`). Jira Automation creates an `Incident` in
a company-managed Jira Software project (`TFCLS`) and links it to the service
request. A second Automation flow labels the Incident and creates its linked RCA
Task. Terraform manages the projects, reusable schemes, Form, and both
Automation flows. [See the Terraform design and configuration.](terraform/README.md)

The Incident workflow then enforces the business rule: an Incident cannot move
to Done until a linked RCA Task exists and is complete. ScriptRunner validators
provide explicit errors, while a Forge context panel shows **RCA missing**,
**RCA incomplete**, or **RCA completed** directly on the Incident. A scheduled
ScriptRunner job marks inconsistent open Incidents with `rca-missing` instead of
silently inventing or deleting relationships.
[See the ScriptRunner rules](scriptrunner/README.md) and
[Forge panel](custom-apps/incident-rca-status/README.md).

Two additional entry points demonstrate integrations beyond the portal: a
ScriptRunner listener creates or reuses an Incident for an urgent Story, and a
signed AWS Lambda webhook handles urgent Bugs with HMAC validation and DynamoDB
idempotency. Both feed the same Incident/RCA model.
[See the listener](scriptrunner/script-listeners/create-incident-for-urgent-story/README.md)
and [signed webhook receiver](webhook/webhook-receiver-aws-lambda/README.md).

```text
JSM portal Form -> Service request -> Jira Software Incident -> RCA Task
                                               |              |
                                               |              +-- must be Done
                                               +-- Forge status and workflow validation
```

## Why it is implemented this way

Terraform manages the Jira spaces, reusable schemes, Form, and both Automation
flows. Human-readable JSON configuration is translated into site-specific Jira
IDs, and a second plan is clean. Small REST adapters cover capabilities missing
from the community provider without exposing those implementation details to
the root configuration. Workflow transitions are deliberately preserved after
creation because Jira stores ScriptRunner-owned rules inside them.
[See the Terraform reconciliation details and limitations.](terraform/README.md)

This is a portfolio demonstration rather than a claim that every production
system should use the same tools. The repository documents the boundaries:
Terraform owns stable configuration, Jira Automation owns RCA creation,
ScriptRunner owns workflow policy and reconciliation, Forge owns the contextual
UI, and the webhook receiver owns external event validation and idempotency.
[See the detailed experiment results and setup guides.](OVERVIEW.md)
