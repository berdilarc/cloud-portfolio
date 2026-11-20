# Landing zone

The Google Cloud foundation for this repository: the organization-level setup that workload projects build on. It is split into stages that are applied in order. Each stage is a separate Terraform root module with its own state.

The layout follows the stage names of [Cloud Foundation Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/master/fast). The code is plain Terraform with `google_*` resources and doesn't use the Fabric modules.

| Stage | Contents |
| --- | --- |
| [`0-org-setup`](0-org-setup/) | IaC core and billing export projects, Workload Identity Federation for GitHub Actions |

Names follow [ADR 0001](../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md).
