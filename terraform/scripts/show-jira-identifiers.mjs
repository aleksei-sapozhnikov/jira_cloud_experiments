/**
 * Displays Jira identifiers derived from the configured site and credentials.
 *
 * Terraform uses the authenticated user's account ID for project leads and the
 * Cloud ID to address the Jira Forms API.
 */

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

const baseUrl = process.env.ATLASSIAN_URL.replace(/\/+$/, '');
const credentials = Buffer.from(
  `${process.env.ATLASSIAN_EMAIL}:${process.env.ATLASSIAN_API_TOKEN}`,
).toString('base64');

async function readJson(url, authenticated = false) {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      ...(authenticated
        ? { Authorization: `Basic ${credentials}` }
        : {}),
    },
  });

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(
      `GET ${url} failed: ${response.status} ${response.statusText}` +
        (responseText ? `\n${responseText}` : ''),
    );
  }

  return responseText ? JSON.parse(responseText) : null;
}

const [currentUser, tenant] = await Promise.all([
  readJson(`${baseUrl}/rest/api/3/myself`, true),
  readJson(`${baseUrl}/_edge/tenant_info`),
]);

console.log(`Jira site: ${baseUrl}`);
console.log(`Cloud ID: ${tenant?.cloudId ?? 'not returned'}`);
console.log(`User: ${currentUser?.displayName ?? 'unknown'}`);
console.log(`Account ID: ${currentUser?.accountId ?? 'not returned'}`);

if (currentUser?.accountId || tenant?.cloudId) {
  console.log('');
  console.log('Add these lines to jira-cloud-iac-dev.env:');

  if (currentUser?.accountId) {
    console.log(
      `TF_VAR_jira_project_lead_account_id=${currentUser.accountId}`,
    );
  }

  if (tenant?.cloudId) {
    console.log(`TF_VAR_jira_cloud_id=${tenant.cloudId}`);
  }

  console.log(`TF_VAR_jira_forms_email=${process.env.ATLASSIAN_EMAIL}`);
  console.log(
    'TF_VAR_jira_forms_api_token=copy-ATLASSIAN_API_TOKEN-value',
  );
}
