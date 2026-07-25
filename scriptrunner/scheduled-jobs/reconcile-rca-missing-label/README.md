# Reconcile the RCA missing label

This example is a ScriptRunner Cloud **Scheduled Job**. It runs once per schedule and performs its own JQL search inside `script.groovy`; no JQL field is required in the ScriptRunner job configuration.

## Schedule and scope

Configure the job to run once per day at **12:00 UTC**.

The scope is defined by `INCIDENT_JQL` at the top of `script.groovy`:

```jql
    project = "TFCLS"
    AND issuetype = "Incident"
AND statusCategory != Done
```

This selects open Incidents in the Terraform Classic Scrum space.

## What the job does

For every Incident returned by the internal search, the job:

1. looks for a linked `Task` carrying the `rca` label;
2. adds `rca-missing` when no such linked work item is found;
3. removes a stale `rca-missing` label after a linked RCA is found;
4. logs and returns a summary of the label changes.

The job does **not** create an RCA Task and does not create missing links. If Automation created an RCA Task but failed to link it to the Incident, the Incident receives `rca-missing` so the inconsistent state can be investigated and repaired manually.

## Configure in ScriptRunner

1. Install `scriptmanager/incident/IncidentRcaService.groovy` in Script Manager as described in [`../../scriptmanager/README.md`](../../scriptmanager/README.md).
2. Navigate to **ScriptRunner → Scheduled Jobs**.
3. Create a job called **RCA missing label reconciliation**.
4. Configure it to run daily at **12:00 UTC**.
5. Review and, if necessary, narrow `INCIDENT_JQL` in `script.groovy`.
6. Copy `script.groovy` into the job code field.
7. Select a user allowed to search and edit the selected Incidents.
8. Use **Run Now** against a small demo scope before enabling the schedule.

## Expected result

After a run:

- every open Incident without a linked RCA Task has the `rca-missing` label;
- an Incident with a linked RCA Task does not retain a stale `rca-missing` label;
- no RCA Tasks or issue links are created by the job.
