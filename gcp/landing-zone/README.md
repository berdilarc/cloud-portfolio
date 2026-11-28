# Landing zone

The Google Cloud foundation for this repository: the organization-level setup that workload projects build on. It is split into stages that are applied in order. Each stage is a separate Terraform root module with its own state.

The layout follows the stage names of [Cloud Foundation Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast). The code is plain Terraform with `google_*` resources and doesn't use the Fabric modules. [ADR 0002](../../docs/decisions/0002-structure-the-landing-zone-as-fast-style-stages-in-plain-terraform.md) explains why.

| Stage | Contents |
| --- | --- |
| [`0-org-setup`](0-org-setup/) | Folders; IaC core, billing export, and audit logs projects; state buckets and service accounts for every stage; and Workload Identity Federation for GitHub Actions |
| [`2-networking`](2-networking/) | Hub and spoke host projects with their VPCs, peering, Cloud NAT, Cloud DNS zones, and firewall policies |

## Hand-off between stages

Stage 0 creates a read-write and a read-only service account for each stage, and keeps the later stages' state in managed folders of one bucket. It also writes the files that a later stage needs to the `outputs` bucket: a providers file with the gcs backend and impersonation for each account, and tfvars files with the identifiers created so far. A stage copies them into its directory before `terraform init`. See [Output files](0-org-setup/README.md#output-files).

Names follow [ADR 0001](../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md).

## Configuration

The values unique to a deployment aren't committed, so that a clone or fork can deploy its own copy without changing tracked files. Every stage reads them from `TF_VAR_*` environment variables. Terraform [ignores environment variables](https://developer.hashicorp.com/terraform/language/values/variables) for variables that a stage doesn't declare.

| Variable | Value | Look it up with |
| --- | --- | --- |
| `TF_VAR_prefix` | Short string that starts every globally unique name | |
| `TF_VAR_org_id` | Numeric ID of the organization | `gcloud organizations list` |
| `TF_VAR_billing_account` | ID of the billing account | `gcloud billing accounts list` |
| `TF_VAR_domain` | Domain of the organization and its groups | `gcloud organizations list` |
| `TF_VAR_github_repository` | Repository, as owner/name | |
| `TF_VAR_github_repository_id` | Numeric ID of the repository | `gh api repos/<github_repository> --jq .id` |
| `TF_VAR_github_repository_owner_id` | Numeric ID of the repository owner | `gh api repos/<github_repository> --jq .owner.id` |

Locally, they come from `mise.local.toml` at the repository root, which `.gitignore` keeps out of the repository. mise loads its `[env]` section in every directory below the root. See [mise configuration](https://mise.jdx.dev/configuration.html). Create it from its template and fill in the values:

```sh
cp mise.local.toml.example mise.local.toml
```

In CI/CD, they come from repository variables, a secret, and the workflow context (see [Setup](#setup)).

## CI/CD

Each stage with CI/CD has a caller workflow that runs the reusable workflow [`terraform.yml`](../../.github/workflows/terraform.yml), with an environment named after the stage and the stage's three CI/CD accounts (see [Service accounts](0-org-setup/README.md#service-accounts)). [`stage-0-org-setup.yml`](../../.github/workflows/stage-0-org-setup.yml) and [`stage-2-networking.yml`](../../.github/workflows/stage-2-networking.yml) each run when a change touches a file other than Markdown in their stage directory, either workflow file, or `mise.toml` and `mise.lock`, which pin Terraform. A caller also lists the earlier stages' tfvars files that its stage needs, in `tfvars_files`. In the table, `<stage>` and `<service_account_prefix>` are the caller's inputs, such as `2-networking` and `iac-networking`.

| Trigger | Job | Account | What it does |
| --- | --- | --- | --- |
| Pull request | `plan` | `<service_account_prefix>-cicd-pr`, as `<service_account_prefix>-ro` | Plans with `-lock=false` and comments a summary on the pull request |
| Push to `main` | `plan` | `<service_account_prefix>-cicd-merge`, as `<service_account_prefix>-ro` | Plans and, if there are changes, saves the plan in `cicd-plans` as `<stage>/<commit>-<run-attempt>.tfplan` |
| Push to `main` | `apply` | `<service_account_prefix>-cicd-apply`, as `<service_account_prefix>-rw` | Waits for approval in the `<stage>` environment, plans again with the state lock, compares the new plan with the saved one, and applies the new plan only if their changes match |

The `apply` job runs only when the merge plan has changes. The saved plan is only compared, never applied: the job applies the plan it made itself. The comparison covers every resource and output change that isn't a no-op, values before the change included, so it also fails if a resource in the plan changed outside Terraform after the merge plan.

A new stage has no state until its first apply. When the gcs backend finds no state, `terraform init` writes an empty one, which the read-only account can't do (see [the backend's source](https://github.com/hashicorp/terraform/blob/main/internal/backend/remote-state/gcs/backend_state.go)). So when `default.tfstate` doesn't exist, the `plan` job writes a `backend_override.tf` with a local backend and plans against an empty local state. Any other error from the check fails the job. The `apply` job always uses the gcs backend, so its read-write account writes the state. To plan such a stage locally, create the same file in the stage directory before `terraform init` (`.gitignore` covers `*_override.tf`), and delete it after the first apply:

```hcl
terraform {
  backend "local" {}
}
```

### Setup

Repository variables and a secret:

| Name | Kind | Value |
| --- | --- | --- |
| `GCP_PREFIX` | Variable | `prefix` |
| `GCP_ORG_ID` | Variable | `org_id` |
| `GCP_BILLING_ACCOUNT` | Variable | `billing_account` |
| `GCP_IAC_PROJECT_NUMBER` | Variable | Number of the IaC core project, for the workload identity provider's name |
| `GCP_DOMAIN` | Secret | `domain` |

For example:

```sh
gh variable set GCP_PREFIX --body <prefix>
gh secret set GCP_DOMAIN --body <domain>
gh secret set GCP_DOMAIN --app dependabot --body <domain>
```

To look up the project number:

```sh
gcloud projects describe <prefix>-prod-iac-core-0 --format "value(projectNumber)"
```

`GCP_DOMAIN` is also a Dependabot secret, because Dependabot pull requests get only Dependabot secrets. They can read repository variables. A job fails if any of these values is empty.

The workflow builds the names of the CI/CD accounts, the buckets, and the workload identity provider from the prefix and the project number, and takes the repository and owner IDs from the `github` [context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#github-context).

Each stage with CI/CD also needs an environment named after the stage, with a required reviewer. Only a job in the environment can impersonate the stage's `-cicd-apply` account, because its Workload Identity User binding is on the `environment:<stage>` subject.
