package incident

/**
 * Shared Incident/RCA operations for the Jira Cloud demonstration.
 *
 * Store this class as incident/IncidentRcaService.groovy in ScriptRunner
 * Script Manager. Entry scripts can then import incident.IncidentRcaService.
 *
 * The listener-facing method creates or reuses only the Incident. RCA Task
 * creation remains the responsibility of the separate Jira Automation rule.
 */
class IncidentRcaService {
    static final String SOURCE_TYPE_NAME = "Story"
    static final String INCIDENT_TYPE_NAME = "Incident"
    static final String RCA_TYPE_NAME = "Task"

    static final String LINK_TYPE_NAME = "Relates"
    static final String RCA_LABEL = "rca"
    static final String RCA_MISSING_LABEL = "rca-missing"
    static final String URGENT_PREFIX = "urgent"

    private final Object logger
    private final Closure getRequest
    private final Closure postRequest
    private final Closure putRequest

    private String jiraBaseUrl

    IncidentRcaService(
        Object logger,
        Closure getRequest,
        Closure postRequest,
        Closure putRequest
    ) {
        this.logger = logger
        this.getRequest = getRequest
        this.postRequest = postRequest
        this.putRequest = putRequest
    }

    /**
     * Return true only for urgent Stories handled by this demonstration.
     */
    boolean isEligibleSource(def sourceWorkItem) {
        String sourceTypeName =
            sourceWorkItem.getWorkType().getAt("name") as String
        String sourceSummary = sourceWorkItem.getSummary()

        return (
            sourceTypeName == SOURCE_TYPE_NAME &&
            sourceSummary != null &&
            sourceSummary.trim().toLowerCase().startsWith(URGENT_PREFIX)
        )
    }

    /**
     * Create or reuse the Incident for one urgent Story and ensure the link.
     *
     * This method intentionally does not create an RCA Task. The separate
     * Jira Automation rule owns that part of the process.
     */
    Map ensureIncidentForUrgentStory(
        def sourceWorkItem,
        String executionSource
    ) {
        String sourceKey = sourceWorkItem.getKey()
        String sourceSummary = sourceWorkItem.getSummary()
        String sourceTypeName =
            sourceWorkItem.getWorkType().getAt("name") as String

        if (!isEligibleSource(sourceWorkItem)) {
            logger.info(
                "${sourceKey}: source does not match the required condition; " +
                "type='${sourceTypeName}', summary='${sourceSummary}'; skipping"
            )
            return [
                source : sourceKey,
                skipped: true
            ]
        }

        String projectKey = getProjectKey(sourceKey)
        String sourceUrl = "${getJiraBaseUrl()}/browse/${sourceKey}"

        Map incidentResult = findOrCreateIncident(
            sourceKey,
            sourceSummary,
            projectKey
        )
        String incidentKey = incidentResult.key as String
        boolean incidentCreated = incidentResult.created as boolean

        /*
         * Create the source link before updating the description. If a later
         * operation fails, another run can find and reuse the Incident.
         */
        ensureLink(sourceKey, incidentKey)

        if (incidentCreated) {
            setIncidentDescription(
                incidentKey,
                sourceKey,
                sourceUrl,
                executionSource
            )
        }

        logger.info(
            "${sourceKey}: Incident processing completed; " +
            "${INCIDENT_TYPE_NAME}=${incidentKey}, " +
            "created=${incidentCreated}"
        )

        return [
            source         : sourceKey,
            sourceType     : SOURCE_TYPE_NAME,
            incident       : incidentKey,
            incidentType   : INCIDENT_TYPE_NAME,
            incidentCreated: incidentCreated,
            projectKey     : projectKey,
            linkType       : LINK_TYPE_NAME,
            skipped        : false
        ]
    }

    /**
     * Add or remove rca-missing according to the linked RCA state.
     *
     * The method never creates or links an RCA Task. A missing link therefore
     * remains visible for manual investigation instead of being guessed at.
     */
    Map reconcileMissingRcaLabel(def incidentWorkItem) {
        String incidentKey = incidentWorkItem.getKey()
        String workTypeName =
            incidentWorkItem.getWorkType().getAt("name") as String

        if (workTypeName != INCIDENT_TYPE_NAME) {
            logger.info(
                "${incidentKey}: work type is '${workTypeName}', " +
                "not '${INCIDENT_TYPE_NAME}'; skipping"
            )
            return [
                incident: incidentKey,
                skipped : true
            ]
        }

        boolean linkedRcaExists = hasLinkedRca(incidentKey)
        List<String> currentLabels = getIssueLabels(incidentKey)
        boolean missingLabelExists =
            currentLabels.contains(RCA_MISSING_LABEL)

        String labelAction = "unchanged"

        if (!linkedRcaExists && !missingLabelExists) {
            updateIssueLabels(
                incidentKey,
                currentLabels + RCA_MISSING_LABEL
            )
            labelAction = "added"
        } else if (linkedRcaExists && missingLabelExists) {
            updateIssueLabels(
                incidentKey,
                currentLabels.findAll {
                    it != RCA_MISSING_LABEL
                }
            )
            labelAction = "removed"
        }

        logger.info(
            "${incidentKey}: RCA missing label reconciliation completed; " +
            "linkedRcaExists=${linkedRcaExists}, " +
            "labelAction=${labelAction}"
        )

        return [
            incident       : incidentKey,
            linkedRcaExists: linkedRcaExists,
            label          : RCA_MISSING_LABEL,
            labelAction    : labelAction,
            skipped        : false
        ]
    }

    private String getProjectKey(String sourceKey) {
        int keySeparatorIndex = sourceKey.lastIndexOf("-")

        if (keySeparatorIndex <= 0) {
            throw new IllegalStateException(
                "Cannot determine project key from source key '${sourceKey}'"
            )
        }

        return sourceKey.substring(0, keySeparatorIndex)
    }

    private String getJiraBaseUrl() {
        if (jiraBaseUrl) {
            return jiraBaseUrl
        }

        def serverInfoResponse = getRequest.call("/rest/api/3/serverInfo")
            .header("Accept", "application/json")
            .asObject(Map)

        if (serverInfoResponse.status != 200) {
            throw new IllegalStateException(
                "Failed to retrieve Jira base URL. " +
                "Status: ${serverInfoResponse.status}; " +
                "response: ${serverInfoResponse.body}"
            )
        }

        Map serverInfoBody = serverInfoResponse.body as Map
        String returnedBaseUrl = serverInfoBody["baseUrl"] as String

        if (!returnedBaseUrl) {
            throw new IllegalStateException(
                "Jira server information does not contain baseUrl. " +
                "Response: ${serverInfoResponse.body}"
            )
        }

        jiraBaseUrl = returnedBaseUrl.replaceAll('/+$', '')
        return jiraBaseUrl
    }

    private Map findOrCreateIncident(
        String sourceKey,
        String sourceSummary,
        String projectKey
    ) {
        String existingIncidentJql = """
            project = "${projectKey}"
            AND issue in linkedIssues("${sourceKey}")
            AND issuetype = "${INCIDENT_TYPE_NAME}"
        """.stripIndent().trim()

        def existingIncidentIterator =
            WorkItems.search(existingIncidentJql).iterator()

        if (existingIncidentIterator.hasNext()) {
            String incidentKey = existingIncidentIterator.next().getKey()
            logger.info(
                "${sourceKey}: linked ${INCIDENT_TYPE_NAME} " +
                "${incidentKey} already exists"
            )
            return [key: incidentKey, created: false]
        }

        String incidentSummary = sourceSummary.take(255)
        def createdIncident = WorkItems.create(
            projectKey,
            INCIDENT_TYPE_NAME
        ) {
            setSummary(incidentSummary)
        }

        String incidentKey = createdIncident.getKey()
        logger.info(
            "${sourceKey}: created ${INCIDENT_TYPE_NAME} " +
            "${incidentKey} in project ${projectKey}"
        )
        return [key: incidentKey, created: true]
    }

    private boolean hasLinkedRca(String incidentKey) {
        String linkedRcaJql = """
            issue in linkedIssues("${incidentKey}")
            AND issuetype = "${RCA_TYPE_NAME}"
            AND labels = "${RCA_LABEL}"
        """.stripIndent().trim()

        return WorkItems.search(linkedRcaJql).iterator().hasNext()
    }

    private List<String> getIssueLabels(String incidentKey) {
        def response = getRequest.call(
            "/rest/api/3/issue/${incidentKey}?fields=labels"
        )
            .header("Accept", "application/json")
            .asObject(Map)

        if (response.status != 200) {
            throw new IllegalStateException(
                "Failed to retrieve labels for ${incidentKey}. " +
                "Status: ${response.status}; response: ${response.body}"
            )
        }

        Map responseBody = response.body as Map
        Map fields = responseBody["fields"] as Map
        List labels = (fields?.get("labels") ?: []) as List

        return labels.collect { it as String }
    }

    private void updateIssueLabels(
        String incidentKey,
        List<String> labels
    ) {
        def response = putRequest.call("/rest/api/3/issue/${incidentKey}")
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .body([
                fields: [
                    labels: labels.unique()
                ]
            ])
            .asString()

        if (response.status != 204) {
            throw new IllegalStateException(
                "Failed to update labels for ${incidentKey}. " +
                "Status: ${response.status}; response: ${response.body}"
            )
        }
    }

    private void ensureLink(String outwardKey, String inwardKey) {
        def linkResponse = postRequest.call("/rest/api/3/issueLink")
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .body([
                type: [
                    name: LINK_TYPE_NAME
                ],
                outwardIssue: [
                    key: outwardKey
                ],
                inwardIssue: [
                    key: inwardKey
                ]
            ])
            .asString()

        if (linkResponse.status != 201) {
            throw new IllegalStateException(
                "Failed to link ${outwardKey} to ${inwardKey}. " +
                "Link type: '${LINK_TYPE_NAME}'; " +
                "status: ${linkResponse.status}; " +
                "response: ${linkResponse.body}"
            )
        }

        logger.info(
            "Ensured '${LINK_TYPE_NAME}' link: " +
            "${outwardKey} -> ${inwardKey}"
        )
    }

    private void setIncidentDescription(
        String incidentKey,
        String sourceKey,
        String sourceUrl,
        String executionSource
    ) {
        def response = putRequest.call("/rest/api/3/issue/${incidentKey}")
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .body([
                fields: [
                    description: [
                        type   : "doc",
                        version: 1,
                        content: [[
                            type   : "paragraph",
                            content: [
                                [
                                    type: "text",
                                    text: "Automatically created by " +
                                        "${executionSource} from "
                                ],
                                [
                                    type : "text",
                                    text : sourceKey,
                                    marks: [[
                                        type : "link",
                                        attrs: [href: sourceUrl]
                                    ]]
                                ],
                                [type: "text", text: "."]
                            ]
                        ]]
                    ]
                ]
            ])
            .asString()

        if (response.status != 204) {
            throw new IllegalStateException(
                "${INCIDENT_TYPE_NAME} ${incidentKey} was created and linked, " +
                "but its description could not be updated. " +
                "Status: ${response.status}; response: ${response.body}"
            )
        }
    }
}
