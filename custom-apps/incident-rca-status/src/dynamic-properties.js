/**
 * Calculates the status displayed next to the collapsed
 * Incident / RCA issue context panel.
 */

import api, { route } from '@forge/api';
import {
  RCA_STATUS,
  calculateRcaStatus,
  getLinkedIssueKeys,
  isRcaIssue,
} from './rca-status';

const createStatus = (label, type) => ({
  status: {
    type: 'lozenge',
    value: {
      label,
      type,
    },
  },
});

const fetchIssue = async (issueKey, fields) => {
  const response = await api.asApp().requestJira(
    route`/rest/api/3/issue/${issueKey}?fields=${fields}`,
    {
      headers: {
        Accept: 'application/json',
      },
    }
  );

  if (!response.ok) {
    const responseBody = await response.text();

    throw new Error(
      `Failed to load ${issueKey}: HTTP ${response.status}. ${responseBody}`
    );
  }

  return response.json();
};

const createRcaStatus = (rcaStatus, rcaIssueCount) => {
  switch (rcaStatus) {
    case RCA_STATUS.MISSING:
      return createStatus('RCA missing', 'removed');
    case RCA_STATUS.MULTIPLE:
      return createStatus(`Multiple RCA: ${rcaIssueCount}`, 'moved');
    case RCA_STATUS.INCOMPLETE:
      return createStatus('RCA incomplete', 'inprogress');
    case RCA_STATUS.COMPLETED:
      return createStatus('RCA completed', 'success');
    default:
      return createStatus('RCA unknown', 'default');
  }
};

export const handler = async (payload) => {
  const issueKey = payload?.extension?.issue?.key;

  console.log(`Calculating RCA status for ${issueKey ?? 'unknown issue'}`);

  if (!issueKey) {
    return createStatus('RCA unknown', 'default');
  }

  try {
    const incident = await fetchIssue(issueKey, 'issuelinks');

    const linkedIssueKeys = getLinkedIssueKeys(
      incident.fields.issuelinks
    );

    const results = await Promise.allSettled(
      linkedIssueKeys.map((linkedIssueKey) =>
        fetchIssue(linkedIssueKey, 'labels,status')
      )
    );

    const linkedIssues = results
      .filter((result) => result.status === 'fulfilled')
      .map((result) => result.value);

    const rcaIssues = linkedIssues.filter(isRcaIssue);
    const rcaStatus = calculateRcaStatus(rcaIssues);

    return createRcaStatus(rcaStatus, rcaIssues.length);
  } catch (error) {
    console.error(
      `Failed to calculate RCA status for ${issueKey}`,
      error
    );

    return createStatus('RCA unknown', 'default');
  }
};
