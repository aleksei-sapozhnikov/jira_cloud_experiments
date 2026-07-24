# Jira configuration with Terraform

[← Back to the portfolio overview](../README.md#terraform-jira-configuration-as-code)

This directory contains the Terraform part of the Jira Cloud demonstration. It creates Jira spaces and reusable configuration profiles, associates the generated schemes with company-managed spaces, and manages a Jira Form through the official Forms REST API.

## Result in brief

After one apply, the demonstration contains:

- two team-managed Jira spaces;
- one company-managed space;
- a reusable workflow, screen, and field-configuration profile;
- project-to-scheme associations reconciled through an idempotent REST helper;
- a `Terraform Incident Report` form with text, radio, checkbox, date, and paragraph questions;
- Terraform outputs with the created space and scheme identifiers.

A second plan in the default `on_terraform_change` mode reports:

```text
No changes. Your infrastructure matches the configuration.
```

This is the shortest successful check for the portfolio demonstration. The `always` mode is a separate drift-reconciliation experiment and intentionally places a reconciliation action in every plan. The script runs only when that plan is applied.

## Table of contents

- [Result in brief](#result-in-brief)
- [What is managed](#what-is-managed)
- [Directory structure](#directory-structure)
- [Configuration files](#configuration-files)
- [Jira Forms module](#jira-forms-module)
- [Profile assignment module](#profile-assignment-module)
- [Authentication and inputs](#authentication-and-inputs)
- [Authentication setup for Jira Forms](#authentication-setup-for-jira-forms)
- [Finding Jira identifiers](#finding-jira-identifiers)
- [Running Terraform](#running-terraform)
- [Reconciliation modes](#reconciliation-modes)
- [Why a REST script is used](#why-a-rest-script-is-used)
- [Why a generic REST provider is used for Forms](#why-a-generic-rest-provider-is-used-for-forms)
- [Important limitations](#important-limitations)
- [State and production usage](#state-and-production-usage)
- [Related documentation](#related-documentation)

## What is managed

The current configuration demonstrates:

- team-managed and company-managed Jira spaces;
- an explicit project lead supplied at runtime;
- workflows and workflow schemes;
- create, edit, and view screens;
- screen schemes and issue-type screen schemes;
- field configurations and field-configuration schemes;
- optional permission schemes where the Jira plan supports them;
- project-to-scheme associations for company-managed spaces;
- Jira form templates with a normal Terraform CRUD lifecycle.

## Directory structure

```text
terraform/
├── config/
│   ├── spaces.json
│   ├── configuration-profiles.json
│   └── forms.json
├── modules/
│   ├── jira-space/
│   ├── jira-configuration-profile/
│   ├── jira-form/
│   └── jira-profile-assignment/
│       └── scripts/
│           └── assign-jira-profile.mjs
├── scripts/
│   └── show-jira-identifiers.mjs
├── main.tf
├── outputs.tf
└── variables.tf
```

## Configuration files

### `config/spaces.json`

Defines Jira spaces. The top-level JSON keys are stable Terraform `for_each` identities; changing one may make Terraform interpret the entry as a removed resource plus a new resource.

The file intentionally contains no user-specific Jira account IDs. All spaces receive their project lead from the root Terraform variable `jira_project_lead_account_id`.

A company-managed space can reference a reusable profile through `configuration_profile`.

### `config/configuration-profiles.json`

Defines reusable Jira configuration objects such as:

- statuses and workflow transitions;
- workflow scheme;
- create/edit/view screens;
- issue-type screen scheme;
- required and hidden fields;
- field-configuration scheme;
- optional permission grants.

Jira statuses are global. The supplied workflow uses distinct Terraform-prefixed status names so that Jira does not reject duplicate global status creation.

### `config/forms.json`

Defines form templates independently from the native Forms API payload. Each top-level key is a stable Terraform identity. `space` references a key from `spaces.json`, `publish.issue_type` names the work type created when the form is submitted, and `form.questions` uses stable numeric IDs and readable question keys.

The demonstration supports `short_text`, `long_text`, `paragraph`, `radio`, `checkboxes`, `dropdown`, `date`, `number`, `email`, and `url`. Choice questions require a non-empty `choices` array.

The work type is selected by its readable name in JSON rather than by a site-specific numeric ID. The root configuration reads the work types belonging to the target space, resolves exactly one matching ID, and passes that ID directly to the form module. The ID is also included in `jira_forms` output for inspection; outputs are not used as inputs inside the same Terraform configuration.

Before the first Forms apply, create the standard-level `Incident` work type in **TFDEMO → Space settings → Work types**. Jira's public issue-type API can read project-scoped work types but cannot create one inside a team-managed space. Terraform reports a targeted validation error if the configured name is absent or ambiguous.

## Jira Forms module

`modules/jira-form` translates the concise JSON definition into the native Jira Forms structure:

- readable question types become Jira's compact type codes such as `ts`, `cs`, and `rt`;
- numeric question IDs connect the question map to ADF layout extension nodes;
- deterministic UUIDv5 values keep ADF node identities stable between plans;
- the configured work type name is resolved to its project-specific ID;
- the form is published for that work type through `publish.jira.issueCreateIssueTypeIds`;
- the generic REST resource owns the returned form ID and performs POST, GET, PUT, and DELETE.

The module intentionally covers a small, useful set of fields. Advanced layout, sections, conditional logic, Jira-field links, request-type publishing, and portal publishing are outside this demonstration rather than being hidden behind an untested universal abstraction.

## Profile assignment module

`modules/jira-profile-assignment` exposes a domain-level interface: a project, the three desired scheme IDs, and a reconciliation mode. The module owns the `terraform_data` resource, change triggers, environment mapping, and idempotent REST helper.

The root configuration passes the same explicit setting to every current module instance:

```hcl
reconciliation_mode = var.jira_profile_reconciliation_mode
```

The root variable defaults to `on_terraform_change`. Override it for a run through `TF_VAR_jira_profile_reconciliation_mode`, the `-var` CLI option, or a literal in the module call. No `.tfvars` file is required.

## Authentication and inputs

The provider and reconciliation scripts use:

```text
ATLASSIAN_URL
ATLASSIAN_EMAIL
ATLASSIAN_API_TOKEN
```

The project lead is a required Terraform variable:

```text
TF_VAR_jira_project_lead_account_id
```

The optional profile-assignment mode defaults to `on_terraform_change`:

```text
TF_VAR_jira_profile_reconciliation_mode
```

The Forms API additionally uses:

```text
TF_VAR_jira_cloud_id
TF_VAR_jira_forms_email
TF_VAR_jira_forms_api_token
```

Terraform automatically maps environment variables named `TF_VAR_<variable_name>` to root module input variables.

The generic REST provider does not read the `ATLASSIAN_*` variables used by the Jira provider. The development container entrypoint automatically maps them to the corresponding `TF_VAR_jira_forms_*` variables, so the email and token are defined only once in `jira-cloud-iac-dev.env`.

## Finding Jira identifiers

After configuring the Jira URL, email, and API token, run from `/workspace`:

```bash
node terraform/scripts/show-jira-identifiers.mjs
```

The helper calls:

- `GET /rest/api/3/myself` to obtain the authenticated user's `accountId`;
- `GET /_edge/tenant_info` to display the site's Cloud ID.

Add the printed lines to the environment file:

```dotenv
TF_VAR_jira_project_lead_account_id=returned-account-id
TF_VAR_jira_cloud_id=returned-cloud-id
```

Restart the container after editing the env file.

Expected result: the script prints the current Jira user, account ID, Cloud ID, and ready-to-copy non-secret Terraform environment-variable lines.

## Authentication setup for Jira Forms

This local Terraform demonstration uses the authentication method Atlassian documents for personal scripts, bots, and ad-hoc Forms API calls: an Atlassian account email with an API token.

Configure the Jira credentials once in the local environment file:

```dotenv
ATLASSIAN_EMAIL=you@example.com
ATLASSIAN_API_TOKEN=your-api-token
```

The container entrypoint reuses these values as `TF_VAR_jira_forms_email` and `TF_VAR_jira_forms_api_token`. Explicit `TF_VAR_*` values still take precedence when supplied. Rebuild and restart the development container after this repository change; Docker reads `--env-file` only at container creation. The API token must belong to a user with the Administer Jira project permission for the target project.

## Running Terraform

Inside the development container, use the `tf` alias. It runs the executable selected by `TF_CLI` in `jira-cloud-iac-dev.env` (`terraform` by default, or `tofu` when OpenTofu is installed in the image):

```bash
cd /workspace/terraform
tf init
tf fmt -recursive
tf validate
```

Expected result: initialization completes, formatting produces no unexpected changes, and validation reports that the configuration is valid.

Review the plan and apply demonstration mode:

```bash
tf plan -out=tfplan
tf apply tfplan
```

Inspect the resulting Terraform outputs:

```bash
tf output jira_spaces
tf output jira_configuration_profiles
tf output jira_profile_assignments
tf output jira_forms
```

Then confirm the stable result:

```bash
tf plan
```

Expected result after the initial application:

- `tf apply` reports `Apply complete`;
- `jira_spaces` lists the configured Jira spaces;
- `jira_configuration_profiles` lists the generated workflow, screen, and field-configuration IDs;
- `jira_profile_assignments` shows the desired project-to-profile associations;
- `jira_forms` shows the form template ID and owning project;
- the subsequent plan reports:

```text
No changes. Your infrastructure matches the configuration.
```

## Reconciliation modes

### `on_terraform_change`

Use this for a clean demonstration. Terraform executes the association script when:

- a managed project ID changes;
- a desired scheme ID changes;
- the reconciliation script changes;
- the resource is created for the first time.

### `always`

Use this when every plan should include a live Jira association check if applied:

```bash
TF_VAR_jira_profile_reconciliation_mode=always \
  tf plan -out=tfplan
tf apply tfplan
```

Expected result: the reconciliation `terraform_data` resource is intentionally replaced, the script checks live Jira associations, and `PUT` requests are sent only for associations that differ.

In this mode every plan proposes replacement of the `terraform_data` reconciliation resource. The replacement and script run occur only when the plan is applied. Jira spaces and schemes are not replaced.

When switching from `always` back to `on_terraform_change`, set the environment variable back to `on_terraform_change` and apply once. The next plan can then be clean.

## Why a REST script is used

The `gothub97/atlassian` provider creates the Jira objects used by this example. The provider version used here does not expose Terraform resources for all required project-to-scheme associations.

The root configuration delegates those associations to `modules/jira-profile-assignment`. Internally, the module invokes:

```text
modules/jira-profile-assignment/scripts/assign-jira-profile.mjs
```

through a private `terraform_data` resource and `local-exec`. Callers only provide the project, desired scheme IDs, profile key, and reconciliation mode.

This REST-backed step is still visible in the Terraform dependency graph and state inputs. The script is idempotent:

1. it reads each current association with `GET`;
2. compares the current scheme ID with the Terraform-generated desired ID;
3. sends `PUT` only when the values differ.

The three reconciled relationships are:

- project → workflow scheme;
- project → issue-type screen scheme;
- project → field-configuration scheme.

## Why a generic REST provider is used for Forms

The selected Jira provider does not expose Jira Forms resources, while Atlassian provides supported create, read, update, and delete endpoints. `Mastercard/restapi` maps those endpoints to a real Terraform resource and retains the server-generated form ID in state.

This is materially different from the association helper above. A create script invoked with `local-exec` cannot return a new form ID into Terraform state, making refresh, drift detection, and destroy unreliable. The generic provider preserves the resource lifecycle without the scope of writing a custom Terraform provider.

For the interview demonstration:

1. apply and show the form in Jira;
2. run a second plan and show `No changes`;
3. edit a label in `config/forms.json` and show an in-place update;
4. destroy only the module instance and show that the template is removed.

## Important limitations

- The workflow-scheme association endpoint used by this example requires an empty company-managed project. Existing work items may require a migration-aware workflow switch.
- Jira Free does not allow creation of custom permission schemes. The supplied profile therefore disables permission-scheme creation.
- An issue-type screen scheme controls screens per work type; it is different from an issue-type scheme that controls which work types exist in the project.
- Team-managed spaces do not use the same shared scheme model as company-managed spaces, so reusable scheme profiles are applied only to company-managed spaces.
- Jira's public API does not create project-scoped work types inside team-managed spaces. Create the configured work type once in the space UI; Terraform then resolves its ID by name and manages the form publication.
- One root variable currently supplies the same project lead to every demo space. Add a separate mapping variable only if the demonstration needs different leads per space.
- The container entrypoint maps Jira credentials to Terraform variables for the generic REST provider; Terraform runs outside the development image must provide those two `TF_VAR_*` variables explicitly.
- The form is published for Jira work-item creation. Publishing to Jira Service Management request types or a customer portal is intentionally omitted.

## State and production usage

Terraform state is intentionally excluded from Git and may contain sensitive data.

For team or production usage:

- use a protected remote backend with locking;
- control access to credentials and state;
- review every plan before applying;
- avoid changing stable `for_each` keys without a deliberate `terraform state mv`;
- test workflow changes in an empty or disposable project before applying them to active projects.

## Related documentation

- [Portfolio overview](../README.md#terraform-jira-configuration-as-code)
- [Forge app](../custom-apps/incident-rca-status/README.md)
