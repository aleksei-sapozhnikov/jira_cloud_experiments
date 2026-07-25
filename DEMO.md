# Jira Incident/RCA automation — two-minute overview

This repository demonstrates how I would evolve a Jira Cloud business process as
a systems engineer: model the stable configuration as code, automate routine
work, enforce governance at workflow boundaries, and leave inconsistent states
visible for operational support.

## What happens in Jira

A user submits the **Terraform Incident Report** through the `TFJSM` customer
portal. Jira Automation creates an `Incident` in the company-managed `TFCLS`
space and links it to the service request. A second Automation flow labels the
Incident, creates a linked RCA Task, and allows the process to continue even
when the Incident was created by another Automation flow.

The Incident workflow then enforces the business rule: an Incident cannot move
to Done until a linked RCA Task exists and is complete. ScriptRunner validators
provide explicit errors, while a Forge context panel shows **RCA missing**,
**RCA incomplete**, or **RCA completed** directly on the Incident. A scheduled
ScriptRunner job marks inconsistent open Incidents with `rca-missing` instead of
silently inventing or deleting relationships.

Two additional entry points demonstrate integrations beyond the portal: a
ScriptRunner listener creates or reuses an Incident for an urgent Story, and a
signed AWS Lambda webhook handles urgent Bugs with HMAC validation and DynamoDB
idempotency. Both feed the same Incident/RCA model.

```text
JSM Form -> Service request -> TFCLS Incident -> RCA Task
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

This is a portfolio demonstration rather than a claim that every production
system should use the same tools. The repository documents the boundaries:
Terraform owns stable configuration, Jira Automation owns RCA creation,
ScriptRunner owns workflow policy and reconciliation, Forge owns the contextual
UI, and the webhook receiver owns external event validation and idempotency.

## Where to continue

- [Portfolio overview and reproduction paths](README.md)
- [Terraform design, reconciliation, and limitations](terraform/README.md)
- [ScriptRunner listeners, jobs, shared code, and validators](scriptrunner/README.md)
- [Forge Incident/RCA panel](custom-apps/incident-rca-status/README.md)
- [Signed AWS Lambda webhook](webhook/webhook-receiver-aws-lambda/README.md)

