# Landing zone

The Google Cloud foundation for this repository: the organization-level setup that workload projects build on. It is split into stages that are applied in order. Each stage is a separate Terraform root module with its own state.

The layout follows the stage names of [Cloud Foundation Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/master/fast). The code is plain Terraform with `google_*` resources and doesn't use the Fabric modules.

| Stage | Contents |
| --- | --- |
| [`0-org-setup`](0-org-setup/) | IaC core and billing export projects, state buckets and service accounts for every stage, Workload Identity Federation for GitHub Actions |

## Hand-off between stages

Stage 0 creates a read-write and a read-only service account for each stage, and keeps the later stages' state in managed folders of one bucket. It also writes the files that a later stage needs to the `outputs` bucket: a providers file with the gcs backend and impersonation for each account, and tfvars files with the identifiers created so far. A stage copies them into its directory before `terraform init`. See [Output files](0-org-setup/README.md#output-files).

Names follow [ADR 0001](../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md).
