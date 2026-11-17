# Bootstrap

Creates the Cloud Storage bucket that stores Terraform state for every stack in this repository, including this one, and the service accounts that CI uses to run Terraform.

## What it creates

Names follow [ADR 0001](../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md).

### State bucket

One bucket named `<project-id>-tf-state` in the seed project. The bucket has:

- object versioning, with a lifecycle rule that deletes a noncurrent version once it has 5 newer versions and has been noncurrent for 30 days;
- uniform bucket-level access and enforced public access prevention;
- `prevent_destroy`, so Terraform refuses to destroy it until that setting is removed.

### CI service accounts

A plan and an apply service account for the foundation stack, with these roles on the state bucket:

| Service account | Runs | Role on the state bucket |
| --- | --- | --- |
| `iac-foundation-ro` | `terraform plan` on pull requests | Storage Object Viewer (`roles/storage.objectViewer`) |
| `iac-foundation-rw` | `terraform apply` after merge | Storage Object User (`roles/storage.objectUser`) |

The plan account cannot write the lock file, so plans that use it must run with `-lock=false`.

The [`gcs` backend documentation](https://developer.hashicorp.com/terraform/language/backend/gcs) asks for Storage Object Admin. Storage Object User is enough to read, write and lock state. Per the [Cloud Storage IAM roles reference](https://docs.cloud.google.com/storage/docs/access-control/iam-roles), Storage Object Admin adds only object IAM and retention permissions, which the backend does not use.

### APIs

The APIs listed in `services` in `terraform.tfvars` are enabled in the seed project. Removing an API from the list does not disable it.

## Prerequisites

- Terraform 1.17.0 or later.
- An existing seed project.
- Application Default Credentials: `gcloud auth application-default login`.
- On the seed project:
  - Storage Admin (`roles/storage.admin`)
  - Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)
  - Service Account Admin (`roles/iam.serviceAccountAdmin`)

## Configuration

| File | Committed | Contents |
| --- | --- | --- |
| `terraform.tfvars` | Yes | `region`, `services` |
| `private.auto.tfvars` | No | `project_id` |
| `backend.hcl` | No | `bucket`, the name of the state bucket |

Create the two uncommitted files from their templates and fill in the values:

```sh
cp private.auto.tfvars.example private.auto.tfvars
cp backend.hcl.example backend.hcl
```

## First run

The stack keeps its state in the bucket it creates, so the bucket has to exist before the `gcs` backend can be used. Apply once with local state, then migrate the state into the bucket.

Override the backend with a local one. Files ending in `_override.tf` are gitignored.

```sh
cp backend_override.tf.example backend_override.tf
terraform init
terraform apply
```

Remove the override and move the state to the bucket. Answer `yes` when Terraform asks to copy the existing state.

```sh
rm backend_override.tf
terraform init -migrate-state -backend-config backend.hcl
terraform plan
```

Once `terraform plan` reports no changes, delete the local `terraform.tfstate` and `terraform.tfstate.backup`.

## Later runs

```sh
terraform init -backend-config backend.hcl
terraform plan
terraform apply
```
