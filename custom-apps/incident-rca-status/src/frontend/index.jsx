/**
 * Displays a compact Incident / RCA process status.
 */

import React from 'react';
import ForgeReconciler, {
  Link,
  SectionMessage,
  Spinner,
  Stack,
  Text,
  useProductContext,
} from '@forge/react';
import { requestJira } from '@forge/bridge';
import {
  RCA_STATUS,
  calculateRcaStatus,
  getLinkedIssueKeys,
  isRcaIssue,
} from '../rca-status';

const fetchIssue = async (issueKey, fields) => {
  const fieldsParameter = encodeURIComponent(fields.join(','));

  const response = await requestJira(
    `/rest/api/3/issue/${encodeURIComponent(
      issueKey
    )}?fields=${fieldsParameter}`,
    {
      headers: {
        Accept: 'application/json',
      },
    }
  );

  if (!response.ok) {
    const body = await response.text();

    throw new Error(
      `Failed to load ${issueKey}: HTTP ${response.status}. ${body}`
    );
  }

  return response.json();
};

const getHealth = (rcaStatus, rcaIssueCount) => {
  switch (rcaStatus) {
    case RCA_STATUS.MISSING:
      return {
        title: 'RCA missing',
        appearance: 'error',
        message: 'No linked issue with the rca label was found.',
      };
    case RCA_STATUS.MULTIPLE:
      return {
        title: 'Multiple RCA tasks found',
        appearance: 'warning',
        message: `${rcaIssueCount} linked RCA tasks were found.`,
      };
    case RCA_STATUS.INCOMPLETE:
      return {
        title: 'RCA incomplete',
        appearance: 'warning',
        message: 'The linked RCA task has not reached Done.',
      };
    case RCA_STATUS.COMPLETED:
      return {
        title: 'RCA completed',
        appearance: 'success',
        message: 'The linked RCA task is completed.',
      };
    default:
      throw new Error(`Unsupported RCA status: ${rcaStatus}`);
  }
};

const App = () => {
  const context = useProductContext();
  const issueKey = context?.extension?.issue?.key;

  const [data, setData] = React.useState(null);
  const [error, setError] = React.useState(null);

  React.useEffect(() => {
    if (!issueKey) {
      return;
    }

    let cancelled = false;

    const load = async () => {
      try {
        setError(null);
        setData(null);

        const incident = await fetchIssue(issueKey, [
          'issuelinks',
        ]);

        const linkedIssueKeys = getLinkedIssueKeys(
          incident.fields.issuelinks
        );

        const linkedIssueResults = await Promise.allSettled(
          linkedIssueKeys.map((linkedIssueKey) =>
            fetchIssue(linkedIssueKey, [
              'summary',
              'status',
              'labels',
            ])
          )
        );

        const linkedIssues = linkedIssueResults
          .filter(
            (result) => result.status === 'fulfilled'
          )
          .map((result) => result.value);

        const rcaIssues = linkedIssues
          .filter(isRcaIssue)
          .sort((first, second) =>
            first.key.localeCompare(second.key)
          );

        if (!cancelled) {
          const rcaStatus = calculateRcaStatus(rcaIssues);

          setData({
            rcaIssues,
            health: getHealth(rcaStatus, rcaIssues.length),
          });
        }
      } catch (loadError) {
        if (!cancelled) {
          setError(
            loadError instanceof Error
              ? loadError.message
              : String(loadError)
          );
        }
      }
    };

    load();

    return () => {
      cancelled = true;
    };
  }, [issueKey]);

  if (!issueKey || (!data && !error)) {
    return <Spinner label="Loading RCA status" />;
  }

  if (error) {
    return (
      <SectionMessage
        appearance="error"
        title="Could not load RCA status"
      >
        <Text>{error}</Text>
      </SectionMessage>
    );
  }

  return (
    <SectionMessage
      appearance={data.health.appearance}
      title={data.health.title}
    >
      <Stack space="space.100">
        <Text>{data.health.message}</Text>

        {data.rcaIssues.map((issue) => (
          <Text key={issue.key}>
            <Link href={`/browse/${issue.key}`}>
              {issue.key}
            </Link>
            {' → '}
            {issue.fields.summary ?? 'No summary'}
          </Text>
        ))}
      </Stack>
    </SectionMessage>
  );
};

ForgeReconciler.render(<App />);
