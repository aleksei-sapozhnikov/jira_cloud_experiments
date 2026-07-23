// Jira expression evaluated before the Groovy listener action.
// Run only for Stories whose summary begins with "urgent".

issue.issueType.name == "Story" &&
    issue.summary != null &&
    issue.summary.trim().toLowerCase().startsWith("urgent")
