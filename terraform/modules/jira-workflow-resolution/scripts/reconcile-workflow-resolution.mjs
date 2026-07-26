/**
 * Reconciles native Jira Resolution post-functions without replacing other
 * workflow rules owned by Jira, ScriptRunner, Forge, or another integration.
 *
 * Every non-initial transition into a DONE status sets Resolution. A directed
 * transition from DONE to another category clears it. A global transition to
 * a non-DONE status also clears it because it can be invoked from DONE.
 */

const [command, encodedConfiguration] = process.argv.slice(2);

if (!['apply', 'validate'].includes(command) || !encodedConfiguration) {
  throw new Error(
    'Usage: reconcile-workflow-resolution.mjs <apply|validate> ' +
      '<base64-configuration>',
  );
}

const requiredVariables = [
  'ATLASSIAN_URL',
  'ATLASSIAN_EMAIL',
  'ATLASSIAN_API_TOKEN',
];

for (const variableName of requiredVariables) {
  if (!process.env[variableName]) {
    throw new Error(`Missing environment variable: ${variableName}`);
  }
}

const configuration = JSON.parse(
  Buffer.from(encodedConfiguration, 'base64').toString('utf8'),
);

const projectId = String(configuration.project_id);
const projectKey = String(configuration.project_key);
const issueTypeIds = [...new Set(configuration.issue_type_ids.map(String))];
const resolutionName = String(configuration.resolution_name);

if (!projectId || !projectKey || issueTypeIds.length === 0 || !resolutionName) {
  throw new Error('Workflow Resolution configuration is incomplete.');
}

const baseUrl = process.env.ATLASSIAN_URL.replace(/\/+$/, '');
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

  return responseText ? JSON.parse(responseText) : null;
}

function normalizedCategory(status) {
  const category = status?.statusCategory;

  if (typeof category === 'string') {
    return category.toUpperCase();
  }

  return String(category?.key ?? category?.name ?? '').toUpperCase();
}

function isResolutionAction(action) {
  return (
    action?.ruleKey === 'system:update-field' &&
    action?.parameters?.field === 'resolution'
  );
}

function desiredResolutionAction(transition, statusByReference, resolutionId) {
  if (String(transition.type).toUpperCase() === 'INITIAL') {
    return null;
  }

  const targetCategory = normalizedCategory(
    statusByReference.get(String(transition.toStatusReference)),
  );

  if (targetCategory === 'DONE') {
    return {
      ruleKey: 'system:update-field',
      parameters: {
        field: 'resolution',
        value: resolutionId,
        mode: 'replace',
      },
    };
  }

  const transitionType = String(transition.type).toUpperCase();
  const sourceReferences = (transition.links ?? [])
    .map((link) => link.fromStatusReference)
    .filter(Boolean)
    .map(String);

  const canLeaveDone =
    transitionType === 'GLOBAL' ||
    sourceReferences.some(
      (reference) =>
        normalizedCategory(statusByReference.get(reference)) === 'DONE',
    );

  if (!canLeaveDone) {
    return null;
  }

  return {
    ruleKey: 'system:update-field',
    parameters: {
      field: 'resolution',
      value: '',
      mode: '',
    },
  };
}

function sameAction(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function reconcileTransition(transition, statusByReference, resolutionId) {
  const desiredAction = desiredResolutionAction(
    transition,
    statusByReference,
    resolutionId,
  );

  if (!desiredAction) {
    return {
      changed: false,
      transition,
    };
  }

  const currentActions = transition.actions ?? [];
  const nonResolutionActions = currentActions.filter(
    (action) => !isResolutionAction(action),
  );
  const currentResolutionActions = currentActions.filter(isResolutionAction);

  if (
    currentResolutionActions.length === 1 &&
    sameAction(
      {
        ruleKey: currentResolutionActions[0].ruleKey,
        parameters: currentResolutionActions[0].parameters,
      },
      desiredAction,
    )
  ) {
    return {
      changed: false,
      transition,
    };
  }

  return {
    changed: true,
    transition: {
      ...transition,
      actions: [...nonResolutionActions, desiredAction],
    },
  };
}

function writableStatus(status) {
  return {
    id: status.id,
    name: status.name,
    statusReference: status.statusReference,
    statusCategory: normalizedCategory(status),
  };
}

function writableWorkflow(workflow, transitions) {
  return {
    id: workflow.id,
    name: workflow.name,
    description: workflow.description ?? '',
    version: workflow.version,
    statuses: (workflow.statuses ?? []).map((status) => ({
      statusReference: status.statusReference,
      properties: status.properties ?? {},
      ...(status.layout ? { layout: status.layout } : {}),
    })),
    transitions,
  };
}

console.log(
  `Reconciling workflow Resolution actions for ` +
    `${projectKey} (${projectId})...`,
);

const [resolutions, workflowResponse] = await Promise.all([
  jiraRequest('/rest/api/3/resolution'),
  jiraRequest('/rest/api/3/workflows', {
    method: 'POST',
    body: JSON.stringify({
      projectAndIssueTypes: issueTypeIds.map((issueTypeId) => ({
        projectId,
        issueTypeId,
      })),
    }),
  }),
]);

const resolutionMatches = resolutions.filter(
  (resolution) =>
    String(resolution.name).toLowerCase() === resolutionName.toLowerCase(),
);

if (resolutionMatches.length !== 1) {
  throw new Error(
    `Expected exactly one Jira Resolution named "${resolutionName}", ` +
      `found ${resolutionMatches.length}.`,
  );
}

const resolutionId = String(resolutionMatches[0].id);
const statusByReference = new Map(
  workflowResponse.statuses.map((status) => [
    String(status.statusReference),
    status,
  ]),
);

const workflowsById = new Map(
  workflowResponse.workflows.map((workflow) => [
    String(workflow.id),
    workflow,
  ]),
);

const changedWorkflows = [];

for (const workflow of workflowsById.values()) {
  let workflowChanged = false;

  const transitions = workflow.transitions.map((transition) => {
    const result = reconcileTransition(
      transition,
      statusByReference,
      resolutionId,
    );

    if (result.changed) {
      workflowChanged = true;
      console.log(
        `${workflow.name}: ${transition.name} will ` +
          `${normalizedCategory(
            statusByReference.get(String(transition.toStatusReference)),
          ) === 'DONE' ? 'set' : 'clear'} Resolution.`,
      );
    }

    return result.transition;
  });

  if (workflowChanged) {
    changedWorkflows.push(writableWorkflow(workflow, transitions));
  }
}

if (changedWorkflows.length === 0) {
  console.log(
    `Workflow Resolution actions are already correct for ${projectKey}.`,
  );
  process.exit(0);
}

const usedStatusReferences = new Set(
  changedWorkflows.flatMap((workflow) =>
    workflow.statuses.map((status) => String(status.statusReference)),
  ),
);

const updatePayload = {
  statuses: workflowResponse.statuses
    .filter((status) =>
      usedStatusReferences.has(String(status.statusReference)),
    )
    .map(writableStatus),
  workflows: changedWorkflows,
};

const validationResponse = await jiraRequest(
  '/rest/api/3/workflows/update/validation',
  {
    method: 'POST',
    body: JSON.stringify({
      payload: updatePayload,
    }),
  },
);

const validationErrors =
  validationResponse?.errors ??
  validationResponse?.validationErrors ??
  [];

if (Array.isArray(validationErrors) && validationErrors.length > 0) {
  throw new Error(
    `Workflow update validation failed:\n` +
      JSON.stringify(validationErrors, null, 2),
  );
}

console.log(
  `Validated ${changedWorkflows.length} workflow update(s) for ${projectKey}.`,
);

if (command === 'validate') {
  process.exit(0);
}

await jiraRequest('/rest/api/3/workflows/update', {
  method: 'POST',
  body: JSON.stringify(updatePayload),
});

console.log(
  `Workflow Resolution actions reconciled for ${projectKey} ` +
    `(${changedWorkflows.length} workflow(s)).`,
);
