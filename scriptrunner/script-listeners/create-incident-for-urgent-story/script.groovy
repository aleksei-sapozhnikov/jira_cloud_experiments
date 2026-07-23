/**
 * ScriptRunner Cloud Script Listener action.
 *
 * condition.js selects newly created urgent Stories. The shared Script Manager
 * service creates or reuses only the linked Incident. RCA Task creation is
 * intentionally left to the separate Jira Automation rule.
 */

import incident.IncidentRcaService

String sourceKey = issue.key as String
def sourceWorkItem = WorkItems.getByKey(sourceKey)

def incidentRcaService = new IncidentRcaService(
    logger,
    { String path -> get(path) },
    { String path -> post(path) },
    { String path -> put(path) }
)

return incidentRcaService.ensureIncidentForUrgentStory(
    sourceWorkItem,
    "ScriptRunner Script Listener"
)
