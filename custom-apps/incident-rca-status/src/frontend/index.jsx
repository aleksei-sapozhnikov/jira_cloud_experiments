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
} from '../shared/rca-status';
import { createJiraRequestError } from '../shared/jira-error';

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
    throw await createJiraRequestError(issueKey, response);
  }

  return response.json();
};

const getHealth = (rcaStatus, rcaIssueCount) => {
  switch (rcaStatus) {
    case RCA_STATUS.UNKNOWN:
      return {
        title: 'RCA status unavailable',
        appearance: 'warning',
        message:
          'We could not retrieve enough information to determine the RCA status.',
      };
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

const getErrorMessage = (error) =>
  error instanceof Error ? error.message : String(error);

/**
 * Renders every RCA state through the same presentation component. Error
 * details and troubleshooting guidance are added only when Jira returned
 * incomplete data.
 */
const RcaStatusMessage = ({
  health,
  rcaIssues = [],
  errors = [],
}) => (
  <SectionMessage
    appearance={health.appearance}
    title={health.title}
  >
    <Stack space="space.100">
      <Text>{health.message}</Text>

      {errors.map((error, index) => (
        <Text key={`${index}-${error}`}>Jira response: {error}</Text>
      ))}

      {errors.length > 0 && (
        <Text>
          Try refreshing the page. If the problem continues, contact your Jira
          administrator.
        </Text>
      )}

      {rcaIssues.map((issue) => (
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

        const linkedIssueErrors = linkedIssueResults
          .filter((result) => result.status === 'rejected')
          .map((result) => getErrorMessage(result.reason));

        const rcaIssues = linkedIssues
          .filter(isRcaIssue)
          .sort((first, second) =>
            first.key.localeCompare(second.key)
          );

        if (!cancelled) {
          const rcaStatus = calculateRcaStatus(rcaIssues, {
            isDataComplete: linkedIssueErrors.length === 0,
          });

          setData({
            rcaIssues,
            errors: linkedIssueErrors,
            health: getHealth(rcaStatus, rcaIssues.length),
          });
        }
      } catch (loadError) {
        if (!cancelled) {
          setError(getErrorMessage(loadError));
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
      <RcaStatusMessage
        health={getHealth(RCA_STATUS.UNKNOWN, 0)}
        errors={[error]}
      />
    );
  }

  return (
    <RcaStatusMessage
      health={data.health}
      rcaIssues={data.rcaIssues}
      errors={data.errors}
    />
  );
};

ForgeReconciler.render(<App />);
