# ScriptRunner for Jira Cloud examples

[← Back to the portfolio overview](../README.md#scriptrunner-cloud-examples)

This directory contains ScriptRunner source used by the Incident/RCA demonstration. The examples cover an event-driven Script Listener, a daily Scheduled Job, reusable Script Manager code, a workflow restriction, and workflow validators.

The repository stores the source files, but does not deploy ScriptRunner configuration automatically. Copy each file into the corresponding ScriptRunner or Jira workflow editor as described below.

## Result in brief

With the selected examples configured:

- a newly created `URGENT` Story creates or reuses a linked Incident;
- a daily job adds `rca-missing` to open Incidents without a linked RCA and removes the stale label after a link appears;
- an Incident closing transition is either hidden or rejected while required RCA work is missing or incomplete.

The listener and Scheduled Job deliberately do not create RCA Tasks. RCA creation belongs to a separate Jira Automation rule, while these examples keep missing or inconsistent relationships visible.

For a quick demonstration, enable the listener and create a Story such as `URGENT: payment export fails`. The expected result is an Incident with the same summary and a `Relates` link back to the Story.

## Directory structure

```text
scriptrunner/
├── scheduled-jobs/
│   └── reconcile-rca-missing-label/
├── script-listeners/
│   └── create-incident-for-urgent-story/
├── scriptmanager/
│   └── incident/
│       └── IncidentRcaService.groovy
├── workflow-restrictions/
│   └── linked-rca-completed/
└── workflow-validators/
    ├── linked-rca-completed/
    └── linked-rca-required/
```

## Languages and file extensions

- `*.groovy` files contain ScriptRunner Groovy classes or entry scripts. The shared class lives in Script Manager; the entry scripts are used by the Script Listener and Scheduled Job.
- `*.js` files contain Jira expressions. ScriptRunner evaluates these expressions for listener conditions, workflow restrictions, and validators. They use JavaScript-like syntax, but run in the Jira Expression Framework rather than Node.js or a browser.

## Script Manager mapping

The repository path `scriptrunner/scriptmanager/incident/IncidentRcaService.groovy` represents `incident/IncidentRcaService.groovy` inside **ScriptRunner → Script Manager**. The `scriptmanager` directory itself is not part of the Groovy package. See [`scriptmanager/README.md`](scriptmanager/README.md).

## Components

| Component | Result | Setup |
| --- | --- | --- |
| Incident/RCA service | Shares Incident creation and `rca-missing` reconciliation logic. | [Install in Script Manager](scriptmanager/incident/) |
| Urgent Story listener | Creates or reuses an Incident when a newly created Story starts with `URGENT`. | [Configure the listener](script-listeners/create-incident-for-urgent-story/) |
| RCA missing label reconciliation | Flags open Incidents that have no linked RCA Task and removes stale flags. | [Configure the Scheduled Job](scheduled-jobs/reconcile-rca-missing-label/) |
| RCA-completed restriction | Hides a transition until linked RCA work exists and is complete. | [Configure the restriction](workflow-restrictions/linked-rca-completed/) |
| RCA-required validator | Rejects a transition when no linked RCA item exists. | [Configure the validator](workflow-validators/linked-rca-required/) |
| RCA-completed validator | Rejects a transition when any linked RCA item is incomplete. | [Configure the validator](workflow-validators/linked-rca-completed/) |

## Shared demo assumptions

The shared Groovy service intentionally uses Jira names instead of environment-specific numeric IDs:

- source work type: `Story`;
- Incident work type: `Incident`;
- RCA work type: `Task`;
- work-item link type: `Relates`;
- RCA label: `rca`;
- missing-RCA label: `rca-missing`;
- urgent-summary prefix: `urgent`, matched case-insensitively.

Change the constants in `scriptmanager/incident/IncidentRcaService.groovy` and the corresponding values in the Jira expressions if a Jira site uses different names.

The expressions use the status-category key `done` rather than a particular status name. This lets custom completion statuses work as long as they belong to Jira's Done status category.

## Expected Jira behavior

With the listener enabled, creating an `URGENT` Story creates or reuses only its linked Incident:

```text
URGENT Story <-> Incident
                    |
                    | separate Jira Automation
                    v
                RCA Task [rca]
```

The listener does not create the RCA Task. When the separate Jira Automation rule is enabled, the new Incident triggers creation of its linked RCA Task.

The Scheduled Job scans open Incidents. It adds `rca-missing` when no linked RCA Task is found and removes the label after the link exists. It never creates an RCA Task or guesses which unlinked Task should be attached, so inconsistent states remain visible for manual investigation.

For Incident closing transitions, use either the restriction or the pair of validators depending on the desired user experience:

- a restriction hides the transition while the requirement is not met;
- validators leave the transition visible and show configured error messages when it is attempted.
