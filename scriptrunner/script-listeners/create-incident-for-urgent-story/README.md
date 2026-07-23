# Create an Incident for an urgent Story

This example is a ScriptRunner Cloud **Script Listener** for newly created Jira work items.

## Files

- `condition.js` — Jira expression evaluated before the listener action;
- `script.groovy` — thin Groovy entry point that calls the shared Script Manager service.

## Condition

The listener runs only when:

- the new work item is a `Story`;
- its summary is not empty;
- its summary starts with `urgent`, case-insensitively.

The shared service repeats the same checks before making changes, so manual execution or a later listener-configuration change cannot bypass the rule accidentally.

## What the action does

For a matching Story, `script.groovy` delegates to `incident.IncidentRcaService`. The service:

1. finds an already linked Incident or creates one in the same project;
2. links the Story and Incident with `Relates`;
3. adds a description to a newly created Incident with a link back to the Story.

The listener does **not** create an RCA Task. RCA creation and the Incident/RCA link belong to the separate Jira Automation rule.

## Configure in ScriptRunner

1. Install `scriptmanager/incident/IncidentRcaService.groovy` in Script Manager as described in [`../../scriptmanager/README.md`](../../scriptmanager/README.md).
2. Navigate to **ScriptRunner → Script Listeners**.
3. Create a listener for the **Work Item Created** event.
4. Select the demo space or spaces.
5. Copy `condition.js` into the condition field.
6. Copy `script.groovy` into the code field.
7. Run it as a user allowed to create, edit, and link work items.
8. Save and enable the listener.

## Expected result

Creating a Story such as `URGENT: payment export fails` creates or reuses:

- an Incident with the same summary;
- a `Relates` link between the Story and Incident.

With Jira Automation disabled, no RCA Task is created by this listener. With the separate Automation rule enabled, the new Incident can then trigger creation of its linked RCA Task.
