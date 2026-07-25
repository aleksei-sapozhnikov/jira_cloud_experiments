const [action, encodedConfiguration] = process.argv.slice(2);

if (!["upsert", "delete", "inspect"].includes(action) || !encodedConfiguration) {
  throw new Error(
    "Usage: reconcile-jira-automation.mjs <upsert|delete|inspect> <base64-configuration>",
  );
}

const configuration = JSON.parse(
  Buffer.from(encodedConfiguration, "base64").toString("utf8"),
);

const email = process.env.ATLASSIAN_EMAIL;
const apiToken = process.env.ATLASSIAN_API_TOKEN;
const jiraUrl = process.env.ATLASSIAN_URL?.replace(/\/+$/, "");

if (!email || !apiToken || !jiraUrl) {
  throw new Error(
    "ATLASSIAN_URL, ATLASSIAN_EMAIL, and ATLASSIAN_API_TOKEN are required.",
  );
}

const authorization = `Basic ${Buffer.from(`${email}:${apiToken}`).toString("base64")}`;
const automationBaseUrl =
  `https://api.atlassian.com/automation/public/jira/${configuration.cloud_id}/rest/v1`;

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: "application/json",
      Authorization: authorization,
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `${options.method ?? "GET"} ${url} returned ${response.status}: ${body}`,
    );
  }

  if (response.status === 204 || response.headers.get("content-length") === "0") {
    return null;
  }

  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

async function findRule(marker) {
  const matches = [];
  let query = "?limit=100";

  while (query) {
    const page = await request(`${automationBaseUrl}/rule/summary${query}`);
    matches.push(
      ...page.data.filter((rule) => rule.description === marker),
    );
    query = page.links?.next ?? null;
  }

  if (matches.length > 1) {
    throw new Error(
      `More than one Jira Automation rule has Terraform marker "${marker}".`,
    );
  }

  return matches[0] ?? null;
}

function preserveComponentIds(desired, current) {
  if (!desired || !current || desired.type !== current.type) {
    return desired;
  }

  if (current.id) {
    desired.id = current.id;
  }

  for (const collection of ["conditions", "children"]) {
    if (Array.isArray(desired[collection]) && Array.isArray(current[collection])) {
      desired[collection] = desired[collection].map((component, index) =>
        preserveComponentIds(component, current[collection][index]),
      );
    }
  }

  return desired;
}

async function currentAccountId() {
  const myself = await request(`${jiraUrl}/rest/api/3/myself`);
  return myself.accountId;
}

async function upsert() {
  const existing = await findRule(configuration.marker);
  const accountId = await currentAccountId();
  const desiredTrigger = structuredClone(configuration.trigger);
  const desiredComponents = structuredClone(configuration.components);

  if (existing) {
    const current = await request(
      `${automationBaseUrl}/rule/${existing.uuid}?redactSensitiveFields=true`,
    );
    preserveComponentIds(desiredTrigger, current.rule.trigger);
    desiredComponents.forEach((component, index) =>
      preserveComponentIds(component, current.rule.components[index]),
    );
  }

  const rule = {
    name: configuration.name,
    state: configuration.enabled ? "ENABLED" : "DISABLED",
    description: configuration.marker,
    canOtherRuleTrigger: configuration.allow_other_rule_triggers,
    notifyOnError: "FIRSTERROR",
    authorAccountId: accountId,
    actor: {
      type: "ACCOUNT_ID",
      actor: accountId,
    },
    trigger: desiredTrigger,
    components: desiredComponents,
    ruleScopeARIs: [
      `ari:cloud:jira:${configuration.cloud_id}:project/${configuration.source_project_id}`,
    ],
    labels: [],
    writeAccessType: "UNRESTRICTED",
    collaborators: [],
    ...(existing ? { uuid: existing.uuid } : {}),
  };

  const body = JSON.stringify({ rule, connections: [] });

  if (existing) {
    await request(`${automationBaseUrl}/rule/${existing.uuid}`, {
      method: "PUT",
      body,
    });
    console.log(`Updated Jira Automation rule ${configuration.name}.`);
  } else {
    await request(`${automationBaseUrl}/rule`, {
      method: "POST",
      body,
    });
    console.log(`Created Jira Automation rule ${configuration.name}.`);
  }
}

async function remove() {
  const existing = await findRule(configuration.marker);
  if (!existing) {
    console.log(`Jira Automation rule ${configuration.marker} is already absent.`);
    return;
  }

  await request(`${automationBaseUrl}/rule/${existing.uuid}/state`, {
    method: "PUT",
    body: JSON.stringify({ value: "DISABLED" }),
  });
  await request(`${automationBaseUrl}/rule/${existing.uuid}`, {
    method: "DELETE",
  });
  console.log(`Deleted Jira Automation rule ${configuration.marker}.`);
}

async function inspect() {
  const existing = await findRule(configuration.marker);
  if (!existing) {
    throw new Error(`Jira Automation rule ${configuration.marker} was not found.`);
  }

  const current = await request(
    `${automationBaseUrl}/rule/${existing.uuid}?redactSensitiveFields=true`,
  );
  console.log(JSON.stringify(current.rule.components, null, 2));
}

await (
  action === "upsert"
    ? upsert()
    : action === "delete"
      ? remove()
      : inspect()
);
