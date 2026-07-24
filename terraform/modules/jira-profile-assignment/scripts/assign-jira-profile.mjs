/**
 * Assigns Terraform-managed Jira schemes to a company-managed project.
 *
 * The script first reads the current associations and only sends PUT
 * requests when the desired scheme is not already assigned.
 */

const requiredVariables = [
  'ATLASSIAN_URL',
  'ATLASSIAN_EMAIL',
  'ATLASSIAN_API_TOKEN',
  'JIRA_PROJECT_ID',
  'JIRA_WORKFLOW_SCHEME_ID',
  'JIRA_ISSUE_TYPE_SCREEN_SCHEME_ID',
  'JIRA_FIELD_CONFIGURATION_SCHEME_ID',
];

for (const variableName of requiredVariables) {
  if (!process.env[variableName]) {
    throw new Error(`Missing environment variable: ${variableName}`);
  }
}

const baseUrl = process.env.ATLASSIAN_URL.replace(/\/+$/, '');
const projectId = String(process.env.JIRA_PROJECT_ID);
const projectKey = process.env.JIRA_PROJECT_KEY ?? projectId;

const credentials = Buffer.from(
  `${process.env.ATLASSIAN_EMAIL}:${process.env.ATLASSIAN_API_TOKEN}`,
).toString('base64');

async function jiraRequest(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      Accept: 'application/json',
      Authorization: `Basic ${credentials}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  });

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(
      `${options.method ?? 'GET'} ${path} failed: ` +
        `${response.status} ${response.statusText}` +
        (responseText ? `\n${responseText}` : ''),
    );
  }

  if (!responseText) {
    return null;
  }

  return JSON.parse(responseText);
}

function containsProject(projectIds) {
  return (
    Array.isArray(projectIds) &&
    projectIds.map(String).includes(projectId)
  );
}

console.log(`Reconciling Jira profile for project ${projectKey} (${projectId})...`);

const assignments = [
  {
    name: 'workflow scheme',

    desiredId: String(process.env.JIRA_WORKFLOW_SCHEME_ID),

    getPath:
      `/rest/api/3/workflowscheme/project` +
      `?projectId=${encodeURIComponent(projectId)}`,

    getCurrentId(response) {
      const association = response?.values?.find((value) =>
        containsProject(value.projectIds),
      );

      return association?.workflowScheme?.id == null
        ? null
        : String(association.workflowScheme.id);
    },

    putPath: '/rest/api/3/workflowscheme/project',

    createBody(desiredId) {
      return {
        projectId,
        workflowSchemeId: desiredId,
      };
    },
  },

  {
    name: 'issue type screen scheme',

    desiredId: String(
      process.env.JIRA_ISSUE_TYPE_SCREEN_SCHEME_ID,
    ),

    getPath:
      `/rest/api/3/issuetypescreenscheme/project` +
      `?projectId=${encodeURIComponent(projectId)}`,

    getCurrentId(response) {
      const association = response?.values?.find((value) =>
        containsProject(value.projectIds),
      );

      return association?.issueTypeScreenScheme?.id == null
        ? null
        : String(association.issueTypeScreenScheme.id);
    },

    putPath: '/rest/api/3/issuetypescreenscheme/project',

    createBody(desiredId) {
      return {
        projectId,
        issueTypeScreenSchemeId: desiredId,
      };
    },
  },

  {
    name: 'field configuration scheme',

    desiredId: String(
      process.env.JIRA_FIELD_CONFIGURATION_SCHEME_ID,
    ),

    getPath:
      `/rest/api/3/fieldconfigurationscheme/project` +
      `?projectId=${encodeURIComponent(projectId)}`,

    getCurrentId(response) {
      const association = response?.values?.find((value) =>
        containsProject(value.projectIds),
      );

      return association?.fieldConfigurationScheme?.id == null
        ? null
        : String(association.fieldConfigurationScheme.id);
    },

    putPath: '/rest/api/3/fieldconfigurationscheme/project',

    createBody(desiredId) {
      return {
        projectId,
        fieldConfigurationSchemeId: desiredId,
      };
    },
  },
];

for (const assignment of assignments) {
  const currentResponse = await jiraRequest(assignment.getPath);
  const currentId = assignment.getCurrentId(currentResponse);

  if (currentId === assignment.desiredId) {
    console.log(
      `${assignment.name}: already assigned ` +
        `(scheme ${assignment.desiredId}).`,
    );

    continue;
  }

  console.log(
    `${assignment.name}: assigning scheme ` +
      `${assignment.desiredId}; current scheme: ${currentId ?? 'default'}.`,
  );

  await jiraRequest(assignment.putPath, {
    method: 'PUT',
    body: JSON.stringify(
      assignment.createBody(assignment.desiredId),
    ),
  });

  console.log(`${assignment.name}: assignment complete.`);
}

console.log(`Jira profile reconciled for project ${projectKey} (${projectId}).`);
