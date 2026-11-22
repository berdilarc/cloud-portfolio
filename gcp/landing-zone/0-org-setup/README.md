# 0-org-setup

The first landing zone stage. It manages the projects that the rest of the landing zone depends on, the state buckets and service accounts of every stage, and lets GitHub Actions authenticate to Google Cloud without keys.

## What it manages

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

### Projects

| Project | Purpose |
| --- | --- |
| `<prefix>-prod-iac-core-0` | Infrastructure as code: state buckets, stage service accounts, Workload Identity Federation for CI |
| `<prefix>-prod-billing-export-0` | BigQuery dataset for the Cloud Billing exports |

Both projects are created under the organization, linked to `billing_account`, and have no default network. Google Cloud creates the default network with the project and Terraform deletes it right away, which enables the Compute Engine API on both projects. See `auto_create_network` in the [`google_project` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project).

The stage manages only the billing export project itself. Its dataset, the exports, and their IAM bindings are configured outside Terraform.

### APIs

The APIs listed in `iac_project_services` in `terraform.tfvars` are enabled in the IaC core project. Removing an API from the list stops Terraform from managing it but leaves it enabled.

### Buckets

Three buckets in the IaC core project, named `<project-id>-<purpose>`, in `region`:

| Purpose | Contents |
| --- | --- |
| `org-state` | State of this stage |
| `stage-state` | State of the later stages, one managed folder per stage |
| `config` | Files that a stage copies into its directory before `terraform init`: generated providers and tfvars files (see [Output files](#output-files)), and private inputs (see [Configuration](#configuration)) |

All three have uniform bucket-level access, enforced public access prevention, and object versioning. A lifecycle rule deletes a noncurrent version once it has 5 newer versions and has been noncurrent for 30 days; an object [has to match all conditions](https://docs.cloud.google.com/storage/docs/lifecycle) of a rule. Terraform refuses to destroy the buckets (`prevent_destroy`).

A fourth bucket, `cicd-plans`, holds the plan files that CI/CD saves between the merge plan and the apply. It has uniform bucket-level access and enforced public access prevention, but no object versioning and no soft delete, and a lifecycle rule deletes objects after 7 days. It has a managed folder for each stage with CI/CD enabled.

`stage-state` has a [managed folder](https://docs.cloud.google.com/storage/docs/managed-folders) for each later stage (`2-networking/`, `2-project-factory/`). Each stage's service accounts get access to their own folder only.

### Service accounts

Each stage has a read-write service account for `terraform apply` and a read-only one for `terraform plan`, all in the IaC core project:

| Stage | Read-write | Read-only |
| --- | --- | --- |
| `0-org-setup` | `iac-org-rw` | `iac-org-ro` |
| `2-networking` | `iac-networking-rw` | `iac-networking-ro` |
| `2-project-factory` | `iac-pf-rw` | `iac-pf-ro` |

Each stage with CI/CD enabled (only `0-org-setup` so far) has three CI/CD accounts, one per workflow trigger. Each one impersonates a stage account:

| Account | Runs | As |
| --- | --- | --- |
| `iac-org-cicd-pr` | `terraform plan` on pull requests | `iac-org-ro` |
| `iac-org-cicd-merge` | `terraform plan` on merges to `main` | `iac-org-ro` |
| `iac-org-cicd-apply` | `terraform apply` after environment approval | `iac-org-rw` |

`iac-agent` is an account for coding agents. It has no roles of its own and can only impersonate the read-only accounts, so an agent given its token can run plans but not applies.

### IAM

The later stages' service accounts get only their state access from this stage, on their managed folder:

| Mode | Role |
| --- | --- |
| Read-write | Storage Object User (`roles/storage.objectUser`) |
| Read-only | Storage Object Viewer (`roles/storage.objectViewer`) |

The read-only accounts can't write the state lock, so their plans run with `-lock=false`.

The stage 0 service accounts get the roles that this stage needs:

| Account | Scope | Roles |
| --- | --- | --- |
| `iac-org-rw` | IaC core project | Service Account Admin, Workload Identity Pool Admin, Project IAM Admin, Service Usage Admin, Storage Admin |
| `iac-org-rw` | Organization | Organization Role Administrator, Security Admin |
| `iac-org-ro` | IaC core project | Service Account Viewer, Workload Identity Pool Viewer, Service Usage Viewer, Storage Viewer with IAM (custom) |
| `iac-org-ro` | Organization | Browser, Security Reviewer |

The custom role `storageViewer` (Storage Viewer with IAM) is defined on the organization. It reads buckets, managed folders, and objects, together with the IAM policies of buckets and managed folders.

The accounts and principals that impersonate others get Service Account Token Creator (`roles/iam.serviceAccountTokenCreator`) on them:

| Principal | Token Creator on |
| --- | --- |
| `local_plan_principals` | Every read-only account and `iac-agent` |
| `local_apply_principals` | Every read-write account |
| `iac-agent` | Every read-only account |
| `iac-org-cicd-pr`, `iac-org-cicd-merge` | `iac-org-ro` |
| `iac-org-cicd-apply` | `iac-org-rw` |

`iac-agent` can't be listed in `local_plan_principals`, since it already gets its bindings, or in `local_apply_principals`. The variable validations reject it in both.

On the stage's managed folder in `cicd-plans`, `iac-org-cicd-merge` gets Storage Object Creator (`roles/storage.objectCreator`) to save the plan, and `iac-org-cicd-apply` gets Storage Object Viewer (`roles/storage.objectViewer`) to read it.

### Workload Identity Federation

A workload identity pool `github` in the IaC core project, with an OIDC provider `github-actions` that trusts tokens from GitHub Actions (`https://token.actions.githubusercontent.com`). The provider:

- accepts a token only if its `repository_id` and `repository_owner_id` claims match `github_repository_id` and `github_repository_owner_id`. [Google recommends the numeric IDs](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) because names can be claimed by someone else after a rename or deletion, and IDs are never reused;
- maps the token's `sub` claim to `google.subject`. See [GitHub's example subject claims](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims).

Workflows impersonate the CI/CD accounts with Workload Identity User (`roles/iam.workloadIdentityUser`), granted per subject:

| Subject | Account |
| --- | --- |
| `repo:<owner>/<repository>:pull_request` | `iac-org-cicd-pr` |
| `repo:<owner>/<repository>:ref:refs/heads/main` | `iac-org-cicd-merge` |
| `repo:<owner>/<repository>:environment:0-org-setup` | `iac-org-cicd-apply` |

The stage accounts have no Workload Identity User bindings. A workflow reaches them only through its CI/CD account.

### Output files

The stage writes these files to the `config` bucket:

| Object | Contents |
| --- | --- |
| `providers/<stage>-providers.tf` | gcs backend and `google` provider, both impersonating the stage's read-write account |
| `providers/<stage>-ro-providers.tf` | The same for the read-only account |
| `tfvars/0-globals.auto.tfvars.json` | Billing account, organization, prefix, and region |
| `tfvars/0-org-setup.auto.tfvars.json` | Custom role, project IDs, service accounts, buckets, and the workload identity provider |

A stage copies the files it needs into its directory. They hold identifiers, so `.gitignore` keeps them out of the repository.

## Prerequisites

- Terraform 1.17.0 or later.
- For plans: membership in `local_plan_principals`.
- For applies: membership in `local_apply_principals`.
- For the first apply, with your own credentials: the roles of `iac-org-rw` listed in [IAM](#iam), plus Project Creator (`roles/resourcemanager.projectCreator`) on the organization and Billing Account User (`roles/billing.user`) on the billing account. See [Creating and managing projects](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects).

## Configuration

| File | Committed | Contents |
| --- | --- | --- |
| `terraform.tfvars` | Yes | `region`, `iac_project_services` |
| `private.auto.tfvars` | No | `prefix`, `org_id`, `billing_account`, `github_repository_id`, `github_repository_owner_id`, `github_repository`, `local_plan_principals`, `local_apply_principals` |

Create the uncommitted file from its template and fill in the values:

```sh
cp private.auto.tfvars.example private.auto.tfvars
```

CI/CD has no copy of the file, so upload it to the `config` bucket after each change:

```sh
gcloud storage cp private.auto.tfvars gs://<prefix>-prod-iac-core-0-config/private/0-org-setup.auto.tfvars
```

To look up the organization and billing account IDs:

```sh
gcloud organizations list
gcloud billing accounts list
```

To look up the repository and owner IDs:

```sh
gh api repos/<owner>/<repository> --jq '.id, .owner.id'
```

## Running

The state is in the `org-state` bucket. To plan as `iac-org-ro`:

```sh
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-ro-providers.tf .
terraform init
terraform plan -lock=false
```

To give a coding agent plan access, mint a short-lived token for `iac-agent` and pass it to the agent in the `GOOGLE_OAUTH_ACCESS_TOKEN` environment variable. With that token, the read-only providers file impersonates `iac-org-ro`:

```sh
gcloud auth print-access-token --impersonate-service-account iac-agent@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
```

To apply as `iac-org-rw`, replace the read-only providers file with the read-write one, since only one of them can be in the directory at a time:

```sh
rm 0-org-setup-ro-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-providers.tf .
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

Then switch back:

```sh
rm tfplan 0-org-setup-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-ro-providers.tf .
terraform init -reconfigure
```

To apply with your own credentials, as for the first apply, use a backend without impersonation instead of the providers file, for example a `backend.tf` that isn't committed:

```hcl
terraform {
  backend "gcs" {
    bucket = "<prefix>-prod-iac-core-0-org-state"
  }
}
```

```sh
terraform init -reconfigure
terraform apply
```

On a new organization the bucket doesn't exist yet: apply once with local state, add the backend, and run `terraform init -migrate-state`.
