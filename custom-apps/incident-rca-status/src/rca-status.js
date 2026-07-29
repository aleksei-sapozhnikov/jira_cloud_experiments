/**
 * Pure business rules shared by the expanded issue panel and its collapsed
 * status. This module deliberately knows nothing about Forge or Jira REST
 * clients, so both runtime environments can use it.
 */

const RCA_LABEL = 'rca';

export const RCA_STATUS = Object.freeze({
  MISSING: 'missing',
  MULTIPLE: 'multiple',
  INCOMPLETE: 'incomplete',
  COMPLETED: 'completed',
});

/**
 * Extracts both inward and outward linked issue keys and removes duplicates.
 */
export const getLinkedIssueKeys = (issueLinks = []) => {
  const keys = issueLinks
    .map((link) => link.outwardIssue?.key ?? link.inwardIssue?.key)
    .filter(Boolean);

  return [...new Set(keys)];
};

/**
 * Identifies the linked tasks that participate in the RCA workflow.
 */
export const isRcaIssue = (issue) =>
  (issue.fields.labels ?? []).includes(RCA_LABEL);

/**
 * Jira considers an issue complete when its status belongs to the Done
 * category, regardless of the workflow-specific status name.
 */
export const isCompleted = (issue) =>
  issue.fields.status?.statusCategory?.key === 'done';

/**
 * Classifies the RCA state without coupling the result to a UI component or
 * dynamic-properties response shape.
 */
export const calculateRcaStatus = (rcaIssues) => {
  if (rcaIssues.length === 0) {
    return RCA_STATUS.MISSING;
  }

  if (rcaIssues.length > 1) {
    return RCA_STATUS.MULTIPLE;
  }

  return isCompleted(rcaIssues[0])
    ? RCA_STATUS.COMPLETED
    : RCA_STATUS.INCOMPLETE;
};
