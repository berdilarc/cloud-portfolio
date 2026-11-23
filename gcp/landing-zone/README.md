# Landing zone

The Google Cloud foundation for this repository: the organization-level setup that workload projects build on. It is split into stages that are applied in order. Each stage is a separate Terraform root module with its own state.

The layout follows the stage names of [Cloud Foundation Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/master/fast). The code is plain Terraform with `google_*` resources and doesn't use the Fabric modules.

| Stage | Contents |
| --- | --- |
| [`0-org-setup`](0-org-setup/) | IaC core and billing export projects, state buckets and service accounts for every stage, Workload Identity Federation for GitHub Actions |

## Hand-off between stages

Stage 0 creates a read-write and a read-only service account for each stage, and keeps the later stages' state in managed folders of one bucket. It also writes the files that a later stage needs to the `config` bucket: a providers file with the gcs backend and impersonation for each account, and tfvars files with the identifiers created so far. A stage copies them into its directory before `terraform init`. See [Output files](0-org-setup/README.md#output-files).

Names follow [ADR 0001](../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md).

## CI/CD

Each stage with CI/CD has a caller workflow that runs the reusable workflow [`terraform.yml`](../../.github/workflows/terraform.yml), with an environment named after the stage and the stage's three CI/CD accounts (see [Service accounts](0-org-setup/README.md#service-accounts)). So far only `0-org-setup` has one: [`stage-0-org-setup.yml`](../../.github/workflows/stage-0-org-setup.yml) runs when a change touches the stage directory, either workflow file, `mise.toml`, or `mise.lock`. Terraform comes from `mise.toml`.

| Trigger | Job | Account | What it does |
| --- | --- | --- | --- |
| Pull request | `plan` | `iac-org-cicd-pr`, as `iac-org-ro` | Plans with `-lock=false` and comments a summary on the pull request |
| Push to `main` | `plan` | `iac-org-cicd-merge`, as `iac-org-ro` | Plans and, if there are changes, saves the plan in `cicd-plans` as `0-org-setup/<commit>-<run-attempt>.tfplan` |
| Push to `main` | `apply` | `iac-org-cicd-apply`, as `iac-org-rw` | Waits for approval in the `0-org-setup` environment, plans again with the state lock, compares the new plan with the saved one, and applies the new plan only if their changes match |

The `apply` job runs only when the merge plan has changes. The saved plan is only compared, never applied: the job applies the plan it made itself. The comparison covers every resource and output change that isn't a no-op, values before the change included, so it also fails if a resource in the plan changed outside Terraform after the merge plan.

Workflow logs and pull request comments are public, so the summary lists only resource addresses and actions, and each job [masks](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#masking-a-value-in-a-log) the project ID, the project number, and the values of the private inputs before running Terraform.

### Setup

Repository secrets, from the outputs of `0-org-setup`:

| Secret | Value |
| --- | --- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` |
| `GCP_CONFIG_BUCKET` | `storage_buckets["config"]` |
| `GCP_CICD_PLANS_BUCKET` | `storage_buckets["cicd-plans"]` |
| `ORG_SETUP_CICD_PR_SA` | `service_accounts["iac-org-cicd-pr"]` |
| `ORG_SETUP_CICD_MERGE_SA` | `service_accounts["iac-org-cicd-merge"]` |

For example:

```sh
gh secret set GCP_CICD_PLANS_BUCKET --body <prefix>-prod-iac-core-0-cicd-plans
```

`GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_CONFIG_BUCKET`, and `ORG_SETUP_CICD_PR_SA` are also Dependabot secrets, so that Dependabot pull requests get a plan.

An environment `0-org-setup` with a required reviewer and the environment secret `CICD_APPLY_SA`, set to `service_accounts["iac-org-cicd-apply"]`:

```sh
gh secret set CICD_APPLY_SA --env 0-org-setup --body iac-org-cicd-apply@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
```

Only a job in the environment can impersonate `iac-org-cicd-apply`, because its Workload Identity User binding is on the `environment:0-org-setup` subject, and such a job [gets environment secrets only after approval](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments). A reusable workflow receives an environment secret only in the job that sets the environment, and [only under its own name](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), so `terraform.yml` declares it as `CICD_APPLY_SA`.
