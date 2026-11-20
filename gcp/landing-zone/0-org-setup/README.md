# 0-org-setup

The first landing zone stage. It manages the projects that the rest of the landing zone depends on, and lets GitHub Actions authenticate to Google Cloud without keys.

## What it manages

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

### Projects

| Project | Purpose |
| --- | --- |
| `<prefix>-prod-iac-core-0` | Infrastructure as code: Workload Identity Federation for CI |
| `<prefix>-prod-billing-export-0` | BigQuery dataset for the Cloud Billing exports |

Both projects are created under the organization, linked to `billing_account`, and have no default network. Google Cloud creates the default network with the project and Terraform deletes it right away, which enables the Compute Engine API on both projects. See `auto_create_network` in the [`google_project` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project).

The stage manages only the billing export project itself. Its dataset, the exports and their IAM bindings are configured outside Terraform.

### APIs

The APIs listed in `iac_project_services` in `terraform.tfvars` are enabled in the IaC core project. Removing an API from the list stops Terraform from managing it but leaves it enabled.

### Workload Identity Federation

A workload identity pool `github` in the IaC core project, with an OIDC provider `github-actions` that trusts tokens from GitHub Actions (`https://token.actions.githubusercontent.com`). The provider:

- accepts a token only if its `repository_id` and `repository_owner_id` claims match `github_repository_id` and `github_repository_owner_id`. [Google recommends the numeric IDs](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) because names can be claimed by someone else after a rename or deletion, and IDs are never reused;
- maps the token's `sub` claim to `google.subject`. See [GitHub's example subject claims](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims).

No roles are granted to identities from the pool, so a federated token has no access to any resource.

## Prerequisites

- Terraform 1.17.0 or later.
- Application Default Credentials: `gcloud auth application-default login`.
- Project Creator (`roles/resourcemanager.projectCreator`) on the organization. See [Creating and managing projects](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects).
- Billing Account User (`roles/billing.user`) on the billing account, to link the projects to it. Terraform also reads the billing account on every plan. See the [`google_project` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project).

The creator of a project is [automatically granted Owner](https://docs.cloud.google.com/resource-manager/docs/access-control-proj) on it, which covers enabling the APIs and creating the workload identity pool.

## Configuration

| File | Committed | Contents |
| --- | --- | --- |
| `terraform.tfvars` | Yes | `iac_project_services` |
| `private.auto.tfvars` | No | `prefix`, `org_id`, `billing_account`, `github_repository_id`, `github_repository_owner_id` |

Create the uncommitted file from its template and fill in the values:

```sh
cp private.auto.tfvars.example private.auto.tfvars
```

To look up the organization and billing account IDs:

```sh
gcloud organizations list
gcloud billing accounts list
```

To look up the repository and owner IDs:

```sh
gh api repos/<owner>/<repo> --jq '.id, .owner.id'
```

## Running

The stage keeps its state locally.

```sh
terraform init
terraform plan
terraform apply
```
