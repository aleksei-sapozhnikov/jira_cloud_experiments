# Jira webhook receiver on AWS Lambda

[← Back to the portfolio overview](../../README.md#aws-lambda-signed-jira-webhook)

This directory contains a small AWS Lambda webhook receiver used by the Jira Cloud demonstration.

The function receives Jira webhook deliveries through a Lambda Function URL. For a newly created Bug whose summary starts with `URGENT`, it creates an Incident in the same Jira project and links the new Incident to the source Bug.

The receiver also:

- validates Jira's `X-Hub-Signature` HMAC signature;
- ignores events that do not match the configured Bug type and `URGENT` summary prefix;
- uses the Atlassian webhook identifier and DynamoDB conditional writes to prevent duplicate processing;
- removes the idempotency record when Incident creation fails so a later delivery can be retried;
- writes processing information to CloudWatch Logs;
- returns a simple health response for `GET` requests.

## Table of contents

- [Files](#files)
- [Processing flow](#processing-flow)
- [Prerequisites](#prerequisites)
- [Create the DynamoDB table](#create-the-dynamodb-table)
- [Create the Lambda function](#create-the-lambda-function)
- [Configure environment variables](#configure-environment-variables)
- [Configure the execution role](#configure-the-execution-role)
- [Create the public Function URL](#create-the-public-function-url)
- [Configure the Jira webhook](#configure-the-jira-webhook)
- [Verify the result](#verify-the-result)
- [Security and implementation notes](#security-and-implementation-notes)

## Files

```text
webhook-receiver-aws-lambda/
├── http_utils.py       # Function URL request and response handling
├── idempotency.py      # DynamoDB duplicate-delivery protection
├── jira_client.py      # Atlassian OAuth and Jira Incident creation
├── lambda_function.py  # AWS Lambda entry point
└── webhook.py          # Signature validation, filtering, and orchestration
```

The AWS Lambda handler is:

```text
lambda_function.lambda_handler
```

## Processing flow

```text
Jira issue-created webhook
→ Lambda Function URL
→ HMAC signature validation
→ event, issue-type, and summary filtering
→ DynamoDB idempotency registration
→ Atlassian OAuth access token
→ Jira REST API creates and links an Incident
→ JSON response and CloudWatch log entry
```

The current filter creates an Incident only when all of the following are true:

- `webhookEvent` is `jira:issue_created`;
- the source work item type ID equals `JIRA_BUG_TYPE_ID`;
- the source summary starts with `URGENT`, case-insensitively.

The Incident is created in the same project as the source Bug. It copies the source summary, includes a browser link to the Bug in its description, and creates the configured Jira issue link during the same REST request.

## Prerequisites

You need:

- an AWS account permitted to create Lambda functions, IAM roles, Function URLs, DynamoDB tables, and CloudWatch log groups;
- a Jira Cloud site where webhooks can be configured;
- an Atlassian OAuth 2.0 client that can create Jira issues and issue links;
- Jira project permissions to create Incidents and link work items;
- the Jira Cloud ID, Bug type ID, Incident type ID, and issue-link type ID;
- a high-entropy webhook secret shared between Jira and the Lambda function.

The classic OAuth scope `write:jira-work` is sufficient for the Jira write operations used by this demo. With granular scopes, grant the equivalent issue and issue-link write scopes required by the Jira REST API.

## Create the DynamoDB table

Create a DynamoDB table in the same AWS Region as the Lambda function.

Recommended demonstration settings:

- table name: any name, for example `jira-webhook-idempotency`;
- partition key: `webhook_id`;
- partition-key type: String;
- sort key: none;
- capacity mode: on-demand;
- Time to Live attribute: `expires_at`.

The function stores each Atlassian webhook identifier with a conditional `PutItem`. A repeated delivery with the same identifier is ignored. Records receive an `expires_at` value seven days in the future; enable DynamoDB TTL for that exact, case-sensitive attribute name so old records can be deleted automatically.

## Create the Lambda function

1. Create a new AWS Lambda function using a supported Python 3 runtime.
2. Use a standard Lambda execution role and add the DynamoDB permissions described below.
3. Set a timeout long enough for the Atlassian OAuth and Jira REST calls. Thirty seconds is sufficient for this demonstration.
4. Package the Python files so they are at the root of the uploaded ZIP archive, not inside an additional parent directory.
5. Upload the ZIP archive to the function.
6. Set the handler to:

```text
lambda_function.lambda_handler
```

Example packaging command from this directory:

```sh
zip jira-webhook-lambda.zip \
  http_utils.py \
  idempotency.py \
  jira_client.py \
  lambda_function.py \
  webhook.py
```

The code uses Python's standard library plus `boto3`, which is available in the AWS Lambda Python runtime.

## Configure environment variables

Configure the following Lambda environment variables.

| Variable | Required by current code | Description |
| --- | --- | --- |
| `ATLASSIAN_CLIENT_ID` | Yes | Client ID for the Atlassian OAuth 2.0 client-credentials flow. |
| `ATLASSIAN_CLIENT_SECRET` | Yes | Client secret for the Atlassian OAuth client. Store it as a secret and do not commit it. |
| `IDEMPOTENCY_TABLE` | Yes | DynamoDB table name used to register webhook identifiers. |
| `JIRA_BASE_URL` | Yes | Jira site URL, for example `https://example.atlassian.net`. Used to build browser links. |
| `JIRA_BUG_TYPE_ID` | Yes | Jira work-item type ID that identifies Bugs accepted by the webhook filter. |
| `JIRA_CLOUD_ID` | Yes | Atlassian Cloud ID used in `https://api.atlassian.com/ex/jira/{cloudId}` REST URLs. |
| `JIRA_INCIDENT_TYPE_ID` | Yes | Jira work-item type ID used when creating the Incident. |
| `JIRA_ISSUE_LINK_TYPE_ID` | Yes | Jira issue-link type ID used to connect the Incident to the source Bug. |
| `JIRA_WEBHOOK_SECRET` | Yes | Secret configured on the Jira webhook and used to validate `X-Hub-Signature`. |

The Jira Cloud ID can be obtained with the repository helper described in the root and Terraform documentation:

```sh
node terraform/scripts/show-jira-identifiers.mjs
```

The type and link IDs are site-specific. Retrieve them from Jira REST APIs or the Jira administration UI rather than copying values from another site.

## Configure the execution role

Attach the standard Lambda basic execution permissions so the function can write CloudWatch Logs.

Add an IAM policy that allows these actions on the configured DynamoDB table:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/TABLE_NAME"
    }
  ]
}
```

Replace `REGION`, `ACCOUNT_ID`, and `TABLE_NAME` with the actual table values.

## Create the public Function URL

Create a Lambda Function URL for the function.

Use:

- authentication type: `NONE`;
- invoke mode: buffered;
- CORS: not required for Jira server-to-server webhook calls.

The URL must be publicly reachable because Jira Cloud sends the webhook from outside the AWS account. The Lambda code provides application-level authentication by checking Jira's HMAC signature before processing a `POST` request.

After creating the Function URL, open it in a browser or call it with `curl`:

```sh
curl https://your-function-url.lambda-url.region.on.aws/
```

Expected response:

```json
{
  "message": "Jira webhook receiver is running"
}
```

A successful health response confirms that the Function URL, handler, and basic deployment are working. It does not verify Jira OAuth, DynamoDB access, or webhook signing.

## Configure the Jira webhook

Create or edit a Jira Cloud webhook with:

- URL: the Lambda Function URL;
- event: work item or issue created;
- secret token: exactly the same value as `JIRA_WEBHOOK_SECRET`;
- optional JQL filter: restrict deliveries to the configured Bug type to reduce unnecessary invocations.

The Lambda function still performs its own checks, even when the Jira webhook has a JQL filter.

Jira signs the raw request body and sends the signature in `X-Hub-Signature`. The function rejects requests whose signature does not match the configured secret.

## Verify the result

1. Open the Function URL with `GET` and confirm the health response.
2. Create a Jira Bug whose summary starts with `URGENT`, for example:

```text
URGENT checkout integration is unavailable
```

3. Confirm that Jira sends the issue-created webhook.
4. Open the Lambda CloudWatch logs and look for the received webhook and created Incident entries.
5. In Jira, verify that:
   - a new Incident exists in the same project;
   - its summary matches the source Bug summary;
   - its description includes a link to the source Bug;
   - the configured Jira issue link connects the Incident and Bug.
6. If the repository's Jira Automation rule is configured, verify that the newly created Incident also causes the linked RCA task to be created. RCA creation is performed by Jira Automation, not by this Lambda function.

The Function URL response for a successful matching webhook contains the source and created work-item IDs and keys, including an `incidentUrl` value.

Non-matching Jira events return `200` with `Webhook ignored`. A repeated delivery with the same `X-Atlassian-Webhook-Identifier` returns `200` with `Duplicate webhook ignored`.

## Security and implementation notes

- A Function URL with authentication type `NONE` is publicly invokable. Do not rely on the URL being difficult to guess; keep signature validation enabled and use a strong secret.
- Store `ATLASSIAN_CLIENT_SECRET` and `JIRA_WEBHOOK_SECRET` in protected Lambda configuration or a secrets-management service.
- The current implementation logs the complete Jira webhook payload. This may contain summaries, user information, and other Jira data. Restrict CloudWatch Logs access and retention accordingly.
- The current `LOG_WEBHOOK_PAYLOAD` variable does not disable payload logging because it is not wired into the repository code.
- The idempotency key is Jira's `X-Atlassian-Webhook-Identifier`, registered atomically with DynamoDB.
- When Jira Incident creation fails, the function deletes the idempotency record so a later delivery can be processed again.
- DynamoDB TTL deletion is asynchronous. An expired item may remain visible for some time after its expiration timestamp.
- This directory contains source code and manual deployment instructions only. It does not currently create the AWS resources as infrastructure as code.
