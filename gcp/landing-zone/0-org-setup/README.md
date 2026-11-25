# 0-org-setup

The first landing zone stage. It manages the folders and projects that the rest of the landing zone depends on, the state buckets and service accounts of every stage, and lets GitHub Actions authenticate to Google Cloud without keys.

## What it manages

### Folders

Two top-level folders under the organization, Networking and Teams. Networking has a Development and a Production folder:

| Folder | Key in `folder_ids` | Holds |
| --- | --- | --- |
| `Networking` | `networking` | `2-networking` projects shared by all environments |
| `Networking/Development` | `networking/dev` | `2-networking` development projects |
| `Networking/Production` | `networking/prod` | `2-networking` production projects |
| `Teams` | `teams` | Team folders and workload projects from `2-project-factory` |

The folders are created after the organization's logging settings, so their `_Default` and `_Required` log buckets are in `region`. They keep the provider's default `deletion_protection`, so Terraform refuses to delete one until it's set to `false`. See the [`google_folder` resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_folder).

### Org policies

The organization gets these policies. Managed constraints, with `managed` in their name, are used where they exist, because they support dry run. See [Organization policy constraints](https://docs.cloud.google.com/organization-policy/reference/org-policy-constraints).

| Constraint | Policy |
| --- | --- |
| `compute.managed.requireOsLogin` | Enforced: VMs must use OS Login |
| `compute.managed.restrictProtocolForwardingCreationForTypes` | Enforced: only internal forwarding rules |
| `compute.skipDefaultNetworkCreation` | Enforced: new projects get no default network |
| `essentialcontacts.managed.allowedContactDomains` | Enforced: Essential Contacts only in the organization's domain |
| `gcp.resourceLocations` | Allows only `resource_locations` for new resources |
| `iam.allowedPolicyMemberDomains` | Allows only identities from the organization's Cloud Identity or Google Workspace account in IAM policies |
| `iam.allowServiceAccountCredentialLifetimeExtension` | Allows `iac-agent` access tokens that last up to 12 hours |
| `iam.automaticIamGrantsForDefaultServiceAccounts` | Enforced: default service accounts get no Editor role |
| `iam.disableServiceAccountKeyUpload` | Enforced |
| `iam.managed.disableServiceAccountKeyCreation` | Enforced |
| `storage.uniformBucketLevelAccess` | Enforced |

The organization's domain and customer ID are read from the organization. A policy applies only to resources created after it's set.

Organizations created on or after May 3, 2024 already enforce seven of these policies. See [Secure by default organizations](https://docs.cloud.google.com/resource-manager/docs/secure-by-default-organizations). On such an organization, import those policies before the first apply, because creating a policy that already exists fails with `409 Conflict`.

### Projects

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

| Project | Purpose |
| --- | --- |
| `<prefix>-prod-iac-core-0` | Infrastructure as code: state buckets, stage service accounts, and Workload Identity Federation for CI |
| `<prefix>-prod-billing-export-0` | BigQuery dataset for the Cloud Billing exports |
| `<prefix>-prod-audit-logs-0` | Audit logs of the organization |

The projects are created under the organization and linked to `billing_account`. They are created after the org policies, so they get no default network, and after the organization's logging settings, so their `_Default` and `_Required` log buckets are in `region`.

The stage manages only the billing export project itself. Its dataset, the exports, and their IAM bindings are configured outside Terraform.

### APIs

The APIs listed in `terraform.tfvars` are enabled in the IaC core project (`iac_project_services`) and the audit logs project (`audit_logs_project_services`). Removing an API from a list stops Terraform from managing it but leaves it enabled.

The stage service accounts live in the IaC core project, so it is the quota project for their API calls: an API that Terraform calls, such as the Cloud Billing API for project billing links, must be enabled there. See [How the quota project is determined](https://docs.cloud.google.com/docs/quotas/quota-project).

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

`config` has a managed folder `private/` for the private inputs, so that uploading them doesn't need write access to the whole bucket.

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

The later stages' service accounts get these roles from this stage:

| Mode | Scope | Role |
| --- | --- | --- |
| Read-write | Their managed folder in `stage-state` | Storage Object User (`roles/storage.objectUser`) |
| Read-only | Their managed folder in `stage-state` | Storage Object Viewer (`roles/storage.objectViewer`) |
| Read-write | Billing account | Billing Account User (`roles/billing.user`) |

The read-only accounts can't write the state lock, so their plans run with `-lock=false`.

The stage 0 service accounts get the roles below. They follow the roles that [FAST's stage 0](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast/stages/0-org-setup/datasets/classic) grants on the organization, its projects, and the billing account, so the stage can manage a new type of resource without first granting itself a role.

| Account | Scope | Roles |
| --- | --- | --- |
| `iac-org-rw` | IaC core project | Owner, Service Account Admin, Workload Identity Pool Admin, Service Usage Admin, and Storage Admin |
| `iac-org-rw` | Billing export and audit logs projects | Owner |
| `iac-org-rw` | Billing account | Billing Account Administrator |
| `iac-org-rw` | Organization | Access Context Manager Admin, Cloud Asset Viewer, Essential Contacts Admin, Folder Admin, IAM Workforce Pool Admin, Logging Admin, Organization Administrator, Organization Policy Administrator, Organization Role Administrator, Project Creator, Project Mover, Tag Administrator, and Tag User |
| `iac-org-ro` | IaC core project | Viewer, Service Account Viewer, Workload Identity Pool Viewer, and Storage Viewer with IAM (custom) |
| `iac-org-ro` | Billing export and audit logs projects | Viewer |
| `iac-org-ro` | Billing account | Billing Account Viewer |
| `iac-org-ro` | Organization | Cloud Asset Viewer, Essential Contacts Viewer, Folder Viewer, IAM Workforce Pool Viewer, Logs Viewer, Organization Admin Viewer (custom), Organization Policy Viewer, Organization Role Viewer, Service Usage Viewer, Tag Viewer, and Tag Viewer with IAM (custom) |

The custom roles are defined on the organization, with the permissions of FAST's roles of the same name:

| Role ID | Title | Reads |
| --- | --- | --- |
| `organizationAdminViewer` | Organization Admin Viewer | The organization, folders, and projects with their IAM policies, org policies, Essential Contacts, logging settings, and bucket IAM policies |
| `storageViewer` | Storage Viewer with IAM | Buckets, managed folders, and objects with their IAM policies, bucket tags, object insights, and multipart uploads |
| `tagViewer` | Tag Viewer with IAM | Tag keys and tag values with their IAM policies, and tag holds |

The accounts and principals that impersonate others get Service Account Token Creator (`roles/iam.serviceAccountTokenCreator`) on them:

| Principal | Token Creator on |
| --- | --- |
| `iac_operators` group | Every read-only account and `iac-agent` |
| `iac-agent` | Every read-only account |
| `iac-org-cicd-pr` and `iac-org-cicd-merge` | `iac-org-ro` |
| `iac-org-cicd-apply` | `iac-org-rw` |

No person gets Token Creator on a read-write account, so only CI/CD applies the stage. See [Break-glass apply](../../../docs/runbooks/0-org-setup-break-glass-apply.md) for the exception, and [Recovery](../../../docs/runbooks/0-org-setup-recovery.md) for when a change breaks the accounts that CI/CD applies with.

On the stage's managed folder in `cicd-plans`, `iac-org-cicd-merge` gets Storage Object Creator (`roles/storage.objectCreator`) to save the plan, and `iac-org-cicd-apply` gets Storage Object Viewer (`roles/storage.objectViewer`) to read it.

On the `config` bucket, the CI/CD accounts get Storage Object Viewer to download the providers file and the private inputs before they impersonate a stage account. On its `private/` managed folder, the `iac_operators` group gets Storage Object User (`roles/storage.objectUser`) to upload the private inputs.

People get their roles through the Cloud Identity groups in `groups`. The stage binds the groups but doesn't create them:

| Group | Scope | Roles |
| --- | --- | --- |
| `organization_admins` | Organization | Advisory Notifications Viewer and Organization Administrator |
| `organization_admins` | Billing account | Billing Account Administrator |
| `iac_operators` | Read-only stage accounts and `iac-agent` | Service Account Token Creator |
| `iac_operators` | `private/` managed folder in `config` | Storage Object User |
| `auditors` | Organization | Cloud Asset Viewer and Security Reviewer |
| `auditors` | Billing account | Billing Account Viewer |
| `auditors` | Audit logs project | Private Logs Viewer, BigQuery Data Viewer, and BigQuery Job User |

The groups split people by what they can affect: organization admins change the organization and billing, which CI/CD normally does for them; IaC operators influence what Terraform does, through plans and private inputs, but can't apply; auditors only read.

### Data Access audit logs

Data Access audit logs are off by default, except for BigQuery. The stage turns them on for these services, as [FAST's stage 0](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast/stages/0-org-setup/datasets/classic) does, including log types that no method of the service uses today:

| Scope | Service | Log types | Records |
| --- | --- | --- | --- |
| Organization | Security Token Service (`sts.googleapis.com`) | Admin Read | Token exchanges, such as Workload Identity Federation sign-ins from GitHub Actions |
| IaC core project | IAM (`iam.googleapis.com`) | Data Read and Data Write | Service account impersonation (Data Read), through the Service Account Credentials API |
| IaC core project | Cloud Storage (`storage.googleapis.com`) | Data Read and Data Write | Reads and writes of state, plans, and configuration files |
| IaC core project | Security Token Service (`sts.googleapis.com`) | Data Read and Data Write | Nothing today: every STS method is Admin Read |

A Data Access audit log turned on at the organization can't be turned off in a folder or project. See [Enable Data Access audit logs](https://docs.cloud.google.com/logging/docs/audit/configure-data-access), [Service Account Credentials audit logging](https://docs.cloud.google.com/iam/docs/audit-logging/audit-logging-iamcreds), and [Security Token Service audit logging](https://docs.cloud.google.com/iam/docs/audit-logging/audit-logging-sts).

The entries go to the `_Default` log bucket of the project where the call happens, and the `iam` sink copies those of IAM, Service Account Credentials, and Security Token Service to the audit logs project (see [Log sinks](#log-sinks)). Reading them needs Private Logs Viewer (`roles/logging.privateLogViewer`) or a role that includes it, such as Security Reviewer.

### Log sinks

Aggregated sinks on the organization copy log entries from every folder and project to the audit logs project, as [FAST's stage 0](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast/stages/0-org-setup/datasets/classic) does. They don't intercept, so the entries also stay in each project's own log buckets.

| Sink | Entries | Destination |
| --- | --- | --- |
| `audit-logs` | Admin Activity, System Event, Policy Denied, and Access Transparency audit logs | `audit-logs` log bucket |
| `iam` | Audit logs of IAM, Service Account Credentials, and Security Token Service | `iam` log bucket |
| `audit-logs-bigquery` | The same entries as `audit-logs` | `audit_logs` BigQuery dataset, one partitioned table per log |

The log buckets are in `region`, keep entries for 30 days, and are upgraded to Log Analytics, which can't be undone. The dataset's partitions also expire after 30 days.

All sinks of the organization write as one Google-managed service account, their writer identity. It gets Logs Bucket Writer on the audit logs project, conditioned on each sink's bucket, and BigQuery Data Editor on the dataset.

Reading a user-defined log bucket goes through its log views, which needs `logging.views.access`: Private Logs Viewer (`roles/logging.privateLogViewer`) and Logs View Accessor have it, but Logs Viewer and Security Reviewer don't. The `auditors` group gets Private Logs Viewer on the audit logs project, which also covers the Data Access entries in the `iam` bucket, and BigQuery roles to query the dataset. See [Log views](https://docs.cloud.google.com/logging/docs/logs-views).

The stage also sets the organization's default storage location for logs to `region`, so projects created from then on get their `_Default` and `_Required` buckets there instead of in `global`.

See [Create an aggregated sink](https://docs.cloud.google.com/logging/docs/export/aggregated_sinks), [Route logs to supported destinations](https://docs.cloud.google.com/logging/docs/export/configure_export_v2), and [Configure default settings for organizations and folders](https://docs.cloud.google.com/logging/docs/default-settings).

### Workload Identity Federation

A workload identity pool `github` in the IaC core project, with an OIDC provider `github-actions` that trusts tokens from GitHub Actions (`https://token.actions.githubusercontent.com`). The provider:

- accepts a token only if its `repository_id` and `repository_owner_id` claims match `github_repository_id` and `github_repository_owner_id`. [Google recommends the numeric IDs](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) because names can be claimed by someone else after a rename or deletion, and IDs are never reused;
- maps the token's `sub` claim to `google.subject`. See [GitHub's example subject claims](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims).

Workflows impersonate the CI/CD accounts with Workload Identity User (`roles/iam.workloadIdentityUser`), granted per subject. The subjects use GitHub's immutable format, which adds the owner and repository IDs to the names. [GitHub uses it for repositories created after July 15, 2026](https://docs.github.com/en/actions/reference/security/oidc), so the stage builds the prefix from `github_repository`, `github_repository_owner_id`, and `github_repository_id`. `<owner>` and `<repository-name>` are the two parts of `github_repository`:

| Subject | Account |
| --- | --- |
| `repo:<owner>@<github_repository_owner_id>/<repository-name>@<github_repository_id>:pull_request` | `iac-org-cicd-pr` |
| `repo:<owner>@<github_repository_owner_id>/<repository-name>@<github_repository_id>:ref:refs/heads/main` | `iac-org-cicd-merge` |
| `repo:<owner>@<github_repository_owner_id>/<repository-name>@<github_repository_id>:environment:0-org-setup` | `iac-org-cicd-apply` |

The stage accounts have no Workload Identity User bindings. A workflow reaches them only through its CI/CD account.

### Output files

The stage writes these files to the `config` bucket:

| Object | Contents |
| --- | --- |
| `providers/<stage>-providers.tf` | gcs backend and `google` provider, both impersonating the stage's read-write account |
| `providers/<stage>-ro-providers.tf` | The same for the read-only account |
| `tfvars/0-globals.auto.tfvars.json` | Billing account, organization, prefix, and region |
| `tfvars/0-org-setup.auto.tfvars.json` | Custom roles, folder IDs, project IDs, service accounts, buckets, and the workload identity provider |

A stage copies the files it needs into its directory. They hold identifiers, so `.gitignore` keeps them out of the repository.

## Prerequisites

- Terraform 1.17.0 or later.
- The groups in `groups`, created by a super admin or a Groups Admin in the Admin console or with `gcloud identity groups create`. See [Create a group in your organization](https://knowledge.workspace.google.com/admin/groups/create-a-group-in-your-organization).
- For plans and for uploading the private inputs: membership in the `iac_operators` group.
- For the first apply, with your own credentials: the roles of `iac-org-rw` listed in [IAM](#iam), including Billing Account Administrator (`roles/billing.admin`) on the billing account. See [Creating and managing projects](https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects) and [Cloud Billing access control](https://docs.cloud.google.com/billing/docs/how-to/billing-access).

## Configuration

| File | Committed | Contents |
| --- | --- | --- |
| `terraform.tfvars` | Yes | `region`, `resource_locations`, `iac_project_services`, and `audit_logs_project_services` |
| `private.auto.tfvars` | No | `prefix`, `org_id`, `billing_account`, `github_repository_id`, `github_repository_owner_id`, `github_repository`, and `groups` |

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
gh api repos/<github_repository> --jq '.id, .owner.id'
```

## Running

The state is in the `org-state` bucket. To plan as `iac-org-ro`, download its providers file as `iac-org-ro` too:

```sh
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-ro-providers.tf . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init
terraform plan -lock=false
```

To give a coding agent plan access, mint a short-lived token for `iac-agent` and pass it to the agent in the `GOOGLE_OAUTH_ACCESS_TOKEN` environment variable. With that token, the read-only providers file impersonates `iac-org-ro`. The token lasts for `--lifetime` seconds, up to 43200 (12 hours):

```sh
gcloud auth print-access-token --impersonate-service-account iac-agent@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --lifetime 28800
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

## CI/CD

Pull requests that change this stage get a plan, and merges to `main` apply it after approval. See [CI/CD](../README.md#cicd).
