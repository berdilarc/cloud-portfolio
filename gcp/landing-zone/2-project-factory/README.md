# 2-project-factory

The project factory stage. It manages the team folders under the Teams folder and the workload projects in them.

## What it manages

### Folders

Each team gets a folder under Teams, with a Development and a Production folder inside it.

| Folder | Key |
| --- | --- |
| Teams/Platform | `platform` |
| Teams/Platform/Development | `platform/dev` |
| Teams/Platform/Production | `platform/prod` |

### Projects

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

| Project | Folder | APIs | Purpose |
| --- | --- | --- | --- |
| `<prefix>-dev-web-0` | Teams/Platform/Development | Compute Engine | Web tier |

The projects are linked to `billing_account`. The organization's org policies stop the default network. Removing an API from a project's list stops Terraform from managing it but leaves it enabled.

## Prerequisites

- Terraform 1.17.0 or later.
- [`0-org-setup`](../0-org-setup/) applied: it creates the Teams folder, the stage's service accounts and their roles, and the state managed folder.
- For plans: membership in the `iac_operators` group of `0-org-setup`.

## Configuration

`prefix` and `billing_account` come from `TF_VAR_*` environment variables. See [Configuration](../README.md#configuration).

`folder_ids` comes from the `0-org-setup` tfvars file. The file holds more values than the stage declares, so Terraform warns about the undeclared ones. See [Values for undeclared variables](https://developer.hashicorp.com/terraform/language/values/variables).

## Running

The state is in the `2-project-factory` managed folder of the `stage-state` bucket. To plan as `iac-pf-ro`, download its providers file and the `0-org-setup` tfvars file. Only the `0-org-setup` accounts and the CI/CD accounts can read the `outputs` bucket, so download them as `iac-org-ro`:

```sh
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/providers/2-project-factory-ro-providers.tf . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/tfvars/0-org-setup.auto.tfvars.json . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init
terraform plan -lock=false
```

## CI/CD

Pull requests that change this stage get a plan, and merges to `main` apply it after approval in the `2-project-factory` environment. See [CI/CD](../README.md#cicd).
