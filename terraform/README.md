# Jira configuration with Terraform

[← Back to the portfolio overview](../README.md#terraform-jira-configuration-as-code)

This directory contains the Terraform part of the Jira Cloud demonstration. It creates Jira spaces and reusable configuration profiles, then associates the generated schemes with company-managed spaces.

## Result in brief

After one apply, the demonstration contains:

- two team-managed Jira spaces;
- one company-managed space;
- a reusable workflow, screen, and field-configuration profile;
- project-to-scheme associations reconciled through an idempotent REST helper;
- Terraform outputs with the created space and scheme identifiers.

A second plan with `config/demo.tfvars` reports:

```text
No changes. Your infrastructure matches the configuration.
```

This is the shortest successful check for the portfolio demonstration. The `always` mode is a separate drift-reconciliation experiment and intentionally produces a reconciliation action on every apply.

## Table of contents

- [Result in brief](#result-in-brief)
- [What is managed](#what-is-managed)
- [Directory structure](#directory-structure)
- [Configuration files](#configuration-files)
- [Authentication and inputs](#authentication-and-inputs)
- [Finding Jira identifiers](#finding-jira-identifiers)
- [Running Terraform](#running-terraform)
- [Reconciliation modes](#reconciliation-modes)
- [Why a REST script is used](#why-a-rest-script-is-used)
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
- project-to-scheme associations for company-managed spaces.

## Directory structure

```text
terraform/
├── config/
│   ├── spaces.json
│   ├── configuration-profiles.json
│   ├── demo.tfvars
│   └── reconcile.tfvars
├── modules/
│   ├── jira-space/
│   └── jira-configuration-profile/
├── scripts/
│   ├── assign-jira-profile.mjs
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

### Reconciliation variable files

`config/demo.tfvars`:

```hcl
jira_profile_reconciliation_mode = "on_change"
```

The REST reconciliation script runs only when desired IDs or the script itself change. After an initial apply, a subsequent plan can show `No changes`.

`config/reconcile.tfvars`:

```hcl
jira_profile_reconciliation_mode = "always"
```

Every apply runs the idempotent association check and repairs manual drift.

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

Terraform automatically maps environment variables named `TF_VAR_<variable_name>` to root module input variables.

When using the root development container, define these values in `jira-cloud-iac-dev.env`, copied from `jira-cloud-iac-dev.env.example`.

## Finding Jira identifiers

After configuring the Jira URL, email, and API token, run from `/workspace`:

```sh
node terraform/scripts/show-jira-identifiers.mjs
```

The helper calls:

- `GET /rest/api/3/myself` to obtain the authenticated user's `accountId`;
- `GET /_edge/tenant_info` to display the site's Cloud ID.

Add the printed line to the environment file:

```dotenv
TF_VAR_jira_project_lead_account_id=returned-account-id
```

Restart the container after editing the env file.

Expected result: the script prints the current Jira user, account ID, Cloud ID, and a ready-to-copy Terraform environment-variable line.

The Cloud ID is informational in this repository. The current Terraform provider and REST reconciliation script call the Jira site through `ATLASSIAN_URL`, so no Cloud ID is stored in configuration.

## Running Terraform

Inside the development container:

```sh
cd /workspace/terraform
terraform init
terraform fmt -recursive
terraform validate
```

Expected result: initialization completes, formatting produces no unexpected changes, and validation reports that the configuration is valid.

Review the plan and apply demonstration mode:

```sh
terraform plan -var-file=config/demo.tfvars -out=tfplan
terraform apply tfplan
```

Inspect the resulting Terraform outputs:

```sh
terraform output jira_spaces
terraform output jira_configuration_profiles
terraform output jira_profile_assignments
```

Then confirm the stable result:

```sh
terraform plan -var-file=config/demo.tfvars
```

Expected result after the initial application:

- `terraform apply` reports `Apply complete`;
- `jira_spaces` lists the configured Jira spaces;
- `jira_configuration_profiles` lists the generated workflow, screen, and field-configuration IDs;
- `jira_profile_assignments` shows the desired project-to-profile associations;
- the subsequent plan reports:

```text
No changes. Your infrastructure matches the configuration.
```

## Reconciliation modes

### `on_change`

Use this for a clean demonstration. Terraform executes the association script when:

- a managed project ID changes;
- a desired scheme ID changes;
- the reconciliation script changes;
- the resource is created for the first time.

### `always`

Use this when every apply should inspect live Jira associations:

```sh
terraform plan -var-file=config/reconcile.tfvars -out=tfplan
terraform apply tfplan
```

Expected result: the reconciliation `terraform_data` resource is intentionally replaced, the script checks live Jira associations, and `PUT` requests are sent only for associations that differ.

In this mode Terraform intentionally replaces the `terraform_data` reconciliation resource on every apply. It does not replace the Jira space or the schemes.

When switching from `always` back to `on_change`, apply `demo.tfvars` once. The next plan can then be clean.

## Why a REST script is used

The `gothub97/atlassian` provider creates the Jira objects used by this example. The provider version used here does not expose Terraform resources for all required project-to-scheme associations.

Terraform therefore invokes:

```text
scripts/assign-jira-profile.mjs
```

through a `terraform_data` resource and `local-exec`.

This REST-backed step is still visible in the Terraform dependency graph and state inputs. The script is idempotent:

1. it reads each current association with `GET`;
2. compares the current scheme ID with the Terraform-generated desired ID;
3. sends `PUT` only when the values differ.

The three reconciled relationships are:

- project → workflow scheme;
- project → issue-type screen scheme;
- project → field-configuration scheme.

## Important limitations

- The workflow-scheme association endpoint used by this example requires an empty company-managed project. Existing work items may require a migration-aware workflow switch.
- Jira Free does not allow creation of custom permission schemes. The supplied profile therefore disables permission-scheme creation.
- An issue-type screen scheme controls screens per work type; it is different from an issue-type scheme that controls which work types exist in the project.
- Team-managed spaces do not use the same shared scheme model as company-managed spaces, so reusable scheme profiles are applied only to company-managed spaces.
- One root variable currently supplies the same project lead to every demo space. Add a separate mapping variable only if the demonstration needs different leads per space.

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
