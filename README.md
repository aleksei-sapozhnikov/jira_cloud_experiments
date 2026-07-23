# Jira Cloud automation portfolio

A collection of independent, reproducible experiments with Jira Cloud administration and automation. The repository covers configuration as code, a Forge UI Kit app, a signed webhook receiver on AWS, ScriptRunner Cloud rules, and a containerized development toolchain.

The examples share one Incident/RCA scenario, but they do not have to be deployed together. Each section starts with the result and links to a focused reproduction guide.

## Results at a glance

| Experiment | Result | What it demonstrates | Reproduction guide |
| --- | --- | --- | --- |
| [Jira configuration with Terraform](#terraform-jira-configuration-as-code) | Creates team-managed and company-managed spaces, reusable workflows, screens, and field configurations. A second demonstration plan is clean. | Terraform modules, JSON-driven configuration, stable resource identities, and idempotent REST reconciliation. | [`terraform/README.md`](terraform/README.md) |
| [Incident / RCA Forge app](#forge-incident--rca-status) | Adds an Incident context panel with **RCA missing**, **RCA incomplete**, or **RCA completed** status. | Forge UI Kit, `issueContext`, Jira REST access, dynamic properties, and minimal scopes. | [`custom-apps/incident-rca-status/README.md`](custom-apps/incident-rca-status/README.md) |
| [Signed Jira webhook on AWS](#aws-lambda-signed-jira-webhook) | Turns a newly created `URGENT` Bug into a linked Incident and ignores duplicate deliveries. | HMAC validation, Atlassian OAuth, Lambda Function URLs, DynamoDB idempotency, and Jira REST writes. | [`webhook/webhook-receiver-aws-lambda/README.md`](webhook/webhook-receiver-aws-lambda/README.md) |
| [ScriptRunner Cloud examples](#scriptrunner-cloud-examples) | Creates Incidents for urgent Stories, reconciles an `rca-missing` label, and protects Incident closing transitions. | Listeners, Scheduled Jobs, Script Manager code, Jira expressions, restrictions, and validators. | [`scriptrunner/README.md`](scriptrunner/README.md) |
| [Reproducible development environment](#shared-development-environment) | Provides Node.js, Forge CLI, and Terraform in one disposable Docker or Podman image. | Repeatable tooling, secret injection, bind mounts, and persistent dependency caches. | [`winutils/README.md`](winutils/README.md) for Windows wrappers |

## Visible outcome

The Forge app exposes the same RCA state in an expanded explanation and a compact collapsed badge:

![RCA completed in expanded and collapsed Forge views](assets/incident-rca-status/rca-completed.png)

The Terraform experiment finishes with a stable follow-up plan:

```text
No changes. Your infrastructure matches the configuration.
```

The automation examples form this optional end-to-end scenario:

```text
URGENT Bug   ── signed webhook + AWS Lambda ──┐
                                              ├──> Incident ── Jira Automation ──> RCA Task [rca]
URGENT Story ── ScriptRunner listener ─────────┘        │
                                                       ├── Forge displays RCA status
                                                       ├── Scheduled Job reconciles rca-missing
                                                       └── workflow rule protects closing
```

The Jira Automation rule that creates the RCA Task is an external part of the demonstration and is not exported by this repository.

## What I explored

- **Where a Terraform provider stops being enough.** The selected provider creates Jira objects, while a small idempotent REST reconciler fills the project-to-scheme association gap.
- **Two reconciliation strategies.** `on_change` produces a clean portfolio demonstration; `always` checks live Jira associations and repairs supported drift on every apply.
- **Native Jira extension with Forge.** A read-only UI Kit app adds operational context without a separate frontend hosting stack.
- **Safe webhook processing.** The Lambda receiver verifies the raw-body HMAC signature before processing and uses a conditional DynamoDB write for delivery idempotency.
- **Automation boundaries.** ScriptRunner creates or checks relationships, Jira Automation owns RCA creation, and inconsistent states remain visible instead of being guessed away.
- **Portable tooling.** Docker and Podman use the same image definition, while optional Windows wrappers select an available runtime automatically.

## Repository layout

```text
.
├── assets/                         # Documentation screenshots
├── custom-apps/
│   └── incident-rca-status/        # Atlassian Forge UI Kit app
├── scriptrunner/                   # Listener, job, shared code, and workflow rules
├── terraform/                      # Jira configuration as code
├── webhook/
│   └── webhook-receiver-aws-lambda/ # Signed Jira webhook receiver
├── winutils/                       # Optional Windows Command Prompt wrappers
├── Dockerfile
└── jira-cloud-iac-dev.env.example
```

## Choose what to reproduce

The experiments have different prerequisites and can be evaluated independently:

| Experiment | Jira access | Additional prerequisites | Deployment model |
| --- | --- | --- | --- |
| Terraform | Jira administrator and API token | Docker or Podman | Automated by Terraform, with a REST-backed association step |
| Forge app | Permission to deploy and install Forge apps | Docker or Podman; Forge credentials | Forge CLI |
| AWS webhook | Permission to create and link work items | AWS account; Atlassian OAuth client | Source is included; AWS resources are configured manually |
| ScriptRunner | ScriptRunner for Jira Cloud | Permission to edit the selected workflows | Source is included; configuration is copied into the Jira and ScriptRunner editors |
| Development image | None for the toolchain check | Docker or Podman | Local container |

For the shortest visual demonstration, deploy the Forge app and open an Incident. For the clearest configuration-as-code demonstration, apply Terraform and show the clean second plan.

## Shared development environment

The root container is used by the Terraform and Forge experiments and by the Jira identifier helper. The AWS and ScriptRunner examples can be reviewed or configured independently.

### Configure credentials

Copy the committed template:

```sh
cp jira-cloud-iac-dev.env.example jira-cloud-iac-dev.env
```

PowerShell:

```powershell
Copy-Item jira-cloud-iac-dev.env.example jira-cloud-iac-dev.env
```

Windows Command Prompt:

```bat
copy jira-cloud-iac-dev.env.example jira-cloud-iac-dev.env
```

Fill in the variables needed by the experiment you selected. `FORGE_API_TOKEN` should contain an Atlassian API scoped token created for Forge. Never commit `jira-cloud-iac-dev.env`; it is excluded by `.gitignore`.

### Build and start the container

Docker:

```sh
docker build -t jira-cloud-iac-dev .
docker run --rm -it \
  --env-file "$PWD/jira-cloud-iac-dev.env" \
  -v npm-cache:/root/.npm \
  -v terraform-plugin-cache:/root/.terraform.d/plugin-cache \
  -v "$PWD:/workspace" \
  -w /workspace \
  -e TF_PLUGIN_CACHE_DIR=/root/.terraform.d/plugin-cache \
  jira-cloud-iac-dev
```

Podman uses the same commands with `podman` in place of `docker`.

PowerShell:

```powershell
docker build -t jira-cloud-iac-dev .
docker run --rm -it `
  --env-file "$PWD/jira-cloud-iac-dev.env" `
  -v npm-cache:/root/.npm `
  -v terraform-plugin-cache:/root/.terraform.d/plugin-cache `
  -v "${PWD}:/workspace" `
  -w /workspace `
  -e TF_PLUGIN_CACHE_DIR=/root/.terraform.d/plugin-cache `
  jira-cloud-iac-dev
```

Windows Command Prompt users can run:

```bat
winutils\container-build.cmd
winutils\container-run.cmd
```

The repository is mounted at `/workspace`. Named volumes retain npm and Terraform provider caches between disposable runs.

### Verify the toolchain and Jira identity

Inside the container:

```sh
pwd
node --version
forge --version
terraform version
forge whoami
node terraform/scripts/show-jira-identifiers.mjs
```

The identifier helper prints the authenticated user, Jira account ID, Cloud ID, and a ready-to-copy Terraform variable:

```text
TF_VAR_jira_project_lead_account_id=712020:example-account-id
```

Add that line to `jira-cloud-iac-dev.env` and restart the container before running Terraform.

**Successful result:** the tools report their versions, Forge shows the intended account, and the helper prints the Jira identifiers without writing them into tracked configuration.

## Terraform: Jira configuration as code

### Result

Terraform creates three demonstration spaces, generates a reusable configuration profile, and associates its workflow, screen, and field-configuration schemes with the company-managed space. The repository supports:

- `on_change` reconciliation for a clean second plan;
- `always` reconciliation for a live association check on every apply.

### Reproduce

Review:

- `terraform/config/spaces.json`;
- `terraform/config/configuration-profiles.json`;
- `TF_VAR_jira_project_lead_account_id` in the local environment file.

Then run inside the development container:

```sh
cd /workspace/terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=config/demo.tfvars -out=tfplan
terraform apply tfplan
terraform output jira_spaces
terraform output jira_configuration_profiles
terraform output jira_profile_assignments
terraform plan -var-file=config/demo.tfvars
```

**Successful result:** `terraform apply` completes, the outputs contain the created spaces and scheme IDs, and the final plan reports no changes.

See [`terraform/README.md`](terraform/README.md) for the configuration schema, reconciliation modes, provider limitation, and production caveats.

## Forge: Incident / RCA status

### Result

The read-only Forge app adds an **Incident / RCA** context panel to Incident work items. It locates linked items carrying the `rca` label and reports:

- **RCA missing** when no matching link exists;
- **RCA incomplete** while at least one matching item is not in Jira's Done status category;
- **RCA completed** when all matching items are done;
- a warning when multiple RCA items need attention.

### Reproduce

Inside the development container:

```sh
cd /workspace/custom-apps/incident-rca-status
npm ci
forge lint
forge deploy --non-interactive -e development
forge install --non-interactive \
  --site "$ATLASSIAN_URL" \
  --product jira \
  --environment development
```

For an existing installation, deploy ordinary code changes again. Use `forge install --non-interactive --upgrade ...` only when scopes or installation permissions change.

**Successful result:** an Incident shows the context panel. **RCA missing** is already a valid smoke test because it proves that the app is installed, rendered, and reading the Incident.

See [`custom-apps/incident-rca-status/README.md`](custom-apps/incident-rca-status/README.md) for app identity, screenshots, deployment lifecycle, and expected states.

## AWS Lambda: signed Jira webhook

### Result

The Python Lambda receiver accepts Jira issue-created webhooks through a public Function URL. For a Bug whose summary starts with `URGENT`, it:

1. verifies Jira's HMAC signature;
2. filters the event and work-item type;
3. registers the webhook identifier atomically in DynamoDB;
4. obtains an Atlassian OAuth access token;
5. creates a same-project Incident and links it to the source Bug.

Repeated deliveries are ignored. A failed Incident creation removes the idempotency record so Jira can retry later.

### Reproduce

The application source is deployable, but the AWS resources are intentionally configured manually in this experiment. Create:

- a DynamoDB table keyed by `webhook_id`, with TTL on `expires_at`;
- a supported Python Lambda with the repository files at the root of its deployment package;
- an execution role with logging plus `dynamodb:PutItem` and `dynamodb:DeleteItem`;
- a public Function URL protected at the application layer by the Jira webhook signature;
- a Jira issue-created webhook using the same high-entropy secret.

**Successful result:** `GET` on the Function URL returns the health response, an `URGENT` Bug produces a linked Incident, and a repeated delivery produces no second Incident.

Follow [`webhook/webhook-receiver-aws-lambda/README.md`](webhook/webhook-receiver-aws-lambda/README.md) for the exact environment variables, IAM policy, packaging command, webhook setup, and security notes.

## ScriptRunner Cloud examples

### Result

The ScriptRunner directory contains four related examples:

| Component | Observable result |
| --- | --- |
| Urgent Story listener | Creates or reuses a linked Incident for a newly created `URGENT` Story. |
| Daily Scheduled Job | Adds `rca-missing` to open Incidents without a linked RCA and removes the stale label after a link appears. |
| Workflow restriction | Hides an Incident closing transition until linked RCA work exists and is complete. |
| Workflow validators | Keep the transition visible but reject it with explicit messages when RCA work is missing or incomplete. |

The listener and job share `IncidentRcaService.groovy` through Script Manager. They do not create RCA Tasks; that responsibility remains with the separate Jira Automation rule.

### Reproduce

1. Recreate `incident/IncidentRcaService.groovy` in **ScriptRunner → Script Manager**.
2. Copy the listener condition and Groovy entry script into a **Work Item Created** Script Listener.
3. Copy the reconciliation script into a daily Scheduled Job and narrow its JQL scope before using it outside a demo site.
4. Configure either the closing-transition restriction or both validators.

**Successful result:** urgent Stories receive linked Incidents, the scheduled reconciliation makes missing RCA relationships visible, and the selected workflow rule prevents premature Incident closing.

See [`scriptrunner/README.md`](scriptrunner/README.md) for assumptions and links to the exact setup guide for every component.

## Important boundaries

- This is a demonstration and learning repository, not a ready-made production platform.
- Terraform does not provision the AWS webhook infrastructure.
- ScriptRunner and Jira workflow configuration are copied manually from version-controlled source.
- The separate Jira Automation rule that creates RCA Tasks is referenced but not exported here.
- Team-managed spaces do not support the same shared-scheme model as company-managed spaces.
- The workflow-scheme association used by the Terraform example is intended for an empty company-managed space.
- The Forge `app.id` identifies one registered application; another developer account needs its own registered app identity.

## Security

Never commit:

- `jira-cloud-iac-dev.env`;
- API tokens or OAuth client secrets;
- Jira webhook secrets;
- Terraform state or saved plans;
- private keys or certificates.

The Lambda Function URL is public and must retain HMAC verification. Terraform state may contain sensitive values; use a protected remote backend with locking before adapting the example for shared or production usage.
