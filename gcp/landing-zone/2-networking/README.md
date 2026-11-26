# 2-networking

The networking stage. It manages the hub and spoke host projects that the workload projects get their networks from.

## What it manages

### Projects

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

| Project | Folder | Purpose |
| --- | --- | --- |
| `<prefix>-prod-net-core-0` | Networking | Hub |
| `<prefix>-dev-net-spoke-0` | Networking/Development | Development spoke |
| `<prefix>-prod-net-spoke-0` | Networking/Production | Production spoke |

The projects are linked to `billing_account`. The organization's org policies stop the default network.

Every host project has the APIs listed in `host_project_services` enabled and is a [Shared VPC host project](https://docs.cloud.google.com/vpc/docs/shared-vpc): projects attached to it as service projects can use its subnets. Removing an API from the list stops Terraform from managing it but leaves it enabled.

### Networks

Each host project has one custom-mode VPC with global dynamic routing and one subnet in `region`, with Private Google Access on. The spoke subnets have secondary ranges reserved for GKE Pods and Services. The ranges of the networks don't overlap, so they can be peered.

| VPC | Project | Subnet | Primary range | Secondary ranges |
| --- | --- | --- | --- | --- |
| `hub-0` | `<prefix>-prod-net-core-0` | `hub-default` | `10.71.0.0/24` | |
| `dev-0` | `<prefix>-dev-net-spoke-0` | `dev-default` | `10.73.0.0/24` | `pods` `10.73.64.0/18`, `services` `10.73.16.0/20` |
| `prod-0` | `<prefix>-prod-net-spoke-0` | `prod-default` | `10.72.0.0/24` | `pods` `10.72.64.0/18`, `services` `10.72.16.0/20` |

## Prerequisites

- Terraform 1.17.0 or later.
- [`0-org-setup`](../0-org-setup/) applied: it creates the folders, the stage's service accounts and their roles, and the state managed folder.
- For plans: membership in the `iac_operators` group of `0-org-setup`.

## Configuration

`terraform.tfvars` holds the choices that any deployment can keep: `region` and `host_project_services`.

`prefix` and `billing_account` come from `TF_VAR_*` environment variables. See [Configuration](../README.md#configuration).

`folder_ids` comes from the `0-org-setup` tfvars file. The file holds more values than the stage declares, so Terraform warns about the undeclared ones. See [Values for undeclared variables](https://developer.hashicorp.com/terraform/language/values/variables).

## Running

The state is in the `2-networking` managed folder of the `stage-state` bucket. To plan as `iac-networking-ro`, download its providers file and the `0-org-setup` tfvars file. Only the `0-org-setup` accounts and the CI/CD accounts can read the `outputs` bucket, so download them as `iac-org-ro`:

```sh
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/providers/2-networking-ro-providers.tf . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/tfvars/0-org-setup.auto.tfvars.json . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init
terraform plan -lock=false
```

## CI/CD

Pull requests that change this stage get a plan, and merges to `main` apply it after approval in the `2-networking` environment. See [CI/CD](../README.md#cicd).
