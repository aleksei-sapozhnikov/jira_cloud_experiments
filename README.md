# Jira Cloud Incident/RCA automation experiments

This repository contains hands-on experiments with Jira Cloud administration
and automation: Terraform-managed configuration, Jira Automation flows,
ScriptRunner Cloud rules, a Jira custom app, a signed AWS webhook, and a
reproducible development container. The examples meet in a small Incident and
root-cause analysis (RCA) process but can also be reviewed independently.
[See the complete portfolio overview and reproduction paths.](OVERVIEW.md)

This is intentionally a portfolio demonstration rather than a proposed
production architecture. One small workflow connects several Jira extension
approaches so their responsibilities and trade-offs can be compared, while
every experiment remains independently reviewable.
[Compare the experiments and their prerequisites.](OVERVIEW.md#choose-what-to-reproduce)

## Incident/RCA workflow

```text
JSM portal Form -> Service request -> Jira Software Incident -> RCA Task
                                               |              |
                                               |              +-- must be Done
                                               +-- RCA status indicator (custom app)
                                               +-- workflow validation
```

### Service request intake

Terraform creates the **Terraform Incident Report** form and publishes it to the
customer portal of a team-managed Jira Service Management project (`TFJSM`).
When a user submits the form, Jira Automation creates a linked `Incident` in a
company-managed Jira Software project (`TFCLS`). A second Automation flow labels
the Incident and creates its linked RCA Task. Terraform also manages the
projects, reusable schemes, and both Automation flows.
[See the Terraform design and configuration.](terraform/README.md)

### Workflow enforcement and reconciliation

The Incident workflow then enforces the business rule: an Incident cannot move
to Done until a linked RCA Task exists and is complete. ScriptRunner validators
provide explicit errors. A scheduled ScriptRunner job marks inconsistent open
Incidents with `rca-missing` instead of silently inventing or deleting
relationships. [See the ScriptRunner rules.](scriptrunner/README.md)

### Custom app RCA status indicator

A custom Jira app shows **RCA missing**, **RCA incomplete**, or **RCA
completed** directly on the Incident. The same state remains visible as a
compact badge when the panel is collapsed.
[See the custom app implementation.](custom-apps/incident-rca-status/README.md)

### Additional incident sources

Two additional entry points create Incidents outside Jira Automation: a
ScriptRunner listener creates or reuses an Incident for an urgent Story, and a
signed AWS Lambda webhook handles urgent Bugs with HMAC validation and DynamoDB
idempotency. Both feed the resulting Incident into the same RCA workflow.
[See the listener](scriptrunner/script-listeners/create-incident-for-urgent-story/README.md)
and [signed webhook receiver](webhook/webhook-receiver-aws-lambda/README.md).

<details>
  <summary><strong>▶ Watch: urgent Story and Bug create linked Incidents</strong></summary>
  <br />
  <img
    src="assets/demos/additional-incident-sources.gif"
    width="960"
    alt="An urgent Story and an urgent Bug each create a linked Incident"
  />
</details>

## GitHub integration

Branch names and pull request titles contain `TFCLS-*` work item keys. Jira's
GitHub integration uses those keys to associate development activity with the
corresponding Jira work items and display branches and pull requests in their
Development panel. The repository history includes demo pull
requests for [Terraform configuration](https://github.com/aleksei-sapozhnikov/jira_cloud_experiments/pull/1),
[Incident/RCA integrations](https://github.com/aleksei-sapozhnikov/jira_cloud_experiments/pull/2),
and the [combined portfolio](https://github.com/aleksei-sapozhnikov/jira_cloud_experiments/pull/3).

## Implementation notes

Terraform manages the Jira spaces, reusable schemes, Form, and both Automation
flows. Human-readable JSON configuration is translated into site-specific Jira
IDs, and a second plan is clean. Small REST adapters cover capabilities missing
from the community provider without exposing those implementation details to
the root configuration. Workflow transitions are deliberately preserved after
creation because Jira stores ScriptRunner-owned rules inside them.
[See the Terraform reconciliation details and limitations.](terraform/README.md)

The responsibility boundaries remain explicit: Terraform owns stable
configuration, Jira Automation owns RCA creation, ScriptRunner owns workflow
policy and reconciliation, the custom app owns the contextual UI, and the
webhook receiver owns external event validation and idempotency.
[See the detailed experiment results and setup guides.](OVERVIEW.md)
