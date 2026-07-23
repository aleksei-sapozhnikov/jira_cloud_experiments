# Incident/RCA service

`IncidentRcaService.groovy` contains shared operations used by the urgent Story listener and the daily RCA missing label Scheduled Job.

It provides two separate behaviors:

- `ensureIncidentForUrgentStory` creates or reuses an Incident and links it to the urgent Story;
- `reconcileMissingRcaLabel` adds or removes `rca-missing` according to whether the Incident has a linked RCA Task.

The service deliberately does not create RCA Tasks. RCA creation belongs to Jira Automation, while an absent link is treated as an inconsistent state that requires manual investigation.

The class uses Jira names instead of environment-specific numeric IDs.

## Install in Script Manager

1. Navigate to **ScriptRunner → Script Manager**.
2. Create a folder named `incident`.
3. Inside it, create `IncidentRcaService.groovy`.
4. Copy the contents of the repository file into the Script Manager editor and save it.

The package declaration is `package incident`, matching the Script Manager folder.
