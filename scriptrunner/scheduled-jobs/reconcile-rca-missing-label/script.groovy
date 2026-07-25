/**
 * ScriptRunner Cloud Scheduled Job.
 *
 * The job scans open Incidents and reconciles the rca-missing label according
 * to whether a linked RCA Task carrying the rca label can be found.
 *
 * It never creates or links RCA Tasks. Missing relationships are flagged for
 * manual investigation instead of being repaired automatically.
 */

import incident.IncidentRcaService

final String INCIDENT_JQL = '''
    project = "TFCLS"
    AND issuetype = "Incident"
    AND statusCategory != Done
'''.stripIndent().trim()

def incidentRcaService = new IncidentRcaService(
    logger,
    { String path -> get(path) },
    { String path -> post(path) },
    { String path -> put(path) }
)

List<Map> results = []

WorkItems.search(INCIDENT_JQL).each { incidentWorkItem ->
    results << incidentRcaService.reconcileMissingRcaLabel(
        incidentWorkItem
    )
}

Map<String, Integer> actionCounts = [
    added    : results.count { it.labelAction == "added" },
    removed  : results.count { it.labelAction == "removed" },
    unchanged: results.count { it.labelAction == "unchanged" },
    skipped  : results.count { it.skipped == true }
]

logger.info(
    "RCA missing label reconciliation completed: " +
    "processed=${results.size()}, " +
    "added=${actionCounts.added}, " +
    "removed=${actionCounts.removed}, " +
    "unchanged=${actionCounts.unchanged}, " +
    "skipped=${actionCounts.skipped}"
)

return [
    jql    : INCIDENT_JQL,
    counts : actionCounts,
    results: results
]
