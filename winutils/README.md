# Windows utilities

[← Back to the shared development environment](../OVERVIEW.md#shared-development-environment)

This directory contains optional Command Prompt wrappers for building and starting the repository development environment on Windows.

## Files

- `container-build.cmd` — builds the `jira-cloud-iac-dev` image from the root `Dockerfile`.
- `container-run.cmd` — starts an interactive development container, mounts the repository at `/workspace`, loads `jira-cloud-iac-dev.env`, and enables persistent npm and Terraform provider caches.

Both scripts can be launched from any current directory. They resolve the repository root relative to their own location.

The container exposes `tf` as a configurable alias for Terraform-compatible commands. `TF_CLI=terraform` is the default in the root env file; set it to `tofu` after installing OpenTofu in the image.

## Container runtime selection

Each script searches `PATH` in this order:

1. `docker`;
2. `podman`.

Docker is used when both are installed. If neither executable is found, the script prints an error and waits for a key press so that a double-clicked Command Prompt window does not close immediately.

The scripts also wait for a key press when a build or container command fails.

## Usage

Create the root credentials file first:

```bat
copy jira-cloud-iac-dev.env.example jira-cloud-iac-dev.env
```

Fill in the values, then run from Command Prompt or by double-clicking:

```bat
winutils\container-build.cmd
winutils\container-run.cmd
```

## Expected result

After `container-build.cmd`:

- the script prints which runtime it selected;
- the `jira-cloud-iac-dev` image is built successfully;
- the window remains open if the build fails.

After `container-run.cmd`:

- the script prints which runtime it selected;
- an interactive container shell opens in `/workspace`;
- a framed startup hint shows which executable the `tf` alias uses;
- the repository is available inside the container;
- npm and Terraform provider caches use persistent named volumes;
- the window remains open if startup fails.

The scripts use the image name:

```text
jira-cloud-iac-dev
```

To force a particular runtime when both are installed, run the equivalent `docker` or `podman` command manually as documented in the [portfolio overview](../OVERVIEW.md#shared-development-environment).

## Related documentation

- [Portfolio overview](../OVERVIEW.md#results-at-a-glance)
- [Forge app](../custom-apps/incident-rca-status/README.md)
- [Terraform configuration](../terraform/README.md)
