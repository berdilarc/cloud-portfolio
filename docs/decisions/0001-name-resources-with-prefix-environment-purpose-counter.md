# 0001. Name resources as prefix, environment, purpose, counter

- Status: accepted
- Date: 2026-11-15

## Context

Every Google Cloud resource in this repository needs a name, and some names are hard to change later:

- A project ID is immutable, globally unique, limited to 30 characters, and cannot be reused after the project is deleted.
- A Cloud Storage bucket name is globally unique and cannot be changed.
- A service account ID is limited to 30 characters.
- A BigQuery dataset ID cannot contain hyphens.

The repository is public. We prefer to keep real project IDs, bucket names, and the domain out of committed files, both for privacy and to avoid hardcoding values that differ per deployment. Names are therefore built from variables.

The organization holds a long-lived shared foundation and short-lived workload projects. There is a single real environment, but the workloads should be able to show a multi-environment layout.

Google publishes two reference conventions: the one in the [enterprise foundations blueprint](https://docs.cloud.google.com/architecture/blueprints/security-foundations/summary#naming-conventions) and the one used by [Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast).

## Decision

We will name resources in the style of Fabric FAST: lowercase, hyphen-separated segments ordered from general to specific, with no resource-type prefix and no random suffix.

| Resource | Pattern | Example |
| --- | --- | --- |
| Folder | Plain display name | `Shared`, `Sandbox`, `Workloads` |
| Project ID | `<prefix>-<env>-<purpose>-<n>` | `<prefix>-prod-iac-core-0` |
| Bucket | `<project-id>-<purpose>` | `<prefix>-prod-iac-core-0-org-state` |
| Service account | `<purpose>-<role>`; for IaC accounts the role is `ro`, `rw`, or `cicd-<trigger>` | `iac-org-rw`, `iac-org-cicd-pr`, `iac-agent` |
| VPC network | `<env>-<purpose>-<n>` | `prod-shared-0` |
| Subnet | `<env>-<purpose>-<region-short>` | `dev-gke-use1` |
| Other project-scoped resources | `<purpose>[-<region-short>]` | `nat-use1` |
| BigQuery dataset | `snake_case` | `billing_export` |
| Group | `gcp-<purpose>@<domain>` | `gcp-org-admins@example.com` |

The segments mean:

- `<prefix>`: one short string for the whole organization, supplied as a Terraform variable. It appears only in globally unique names (project IDs and bucket names).
- `<env>`: `prod` or `dev`. The shared foundation uses `prod`. Workload projects use `dev`, and `prod` where a workload is deployed to a second environment.
- `<purpose>`: one to three short words that say what the resource is for.
- `<n>`: a counter starting at `0`. A replacement for a deleted project takes the next number.
- `<region-short>`: the region without hyphens and with the area abbreviated, such as `use1` for `us-east1`.

Anything else worth recording about a resource (owner, cost attribution) goes in labels, not in the name.

## Alternatives considered

**Enterprise foundations blueprint convention** (`prj-c-logging-a1b2`, `vpc-p-svpc`, `sa-terraform-net`, `bkt-<project-id>-<description>`). Not chosen because:

- The random project suffix means an ID is unknown until it is created, so documentation and commands cannot name a project in advance and every reference has to pass through a Terraform output.
- Type prefixes such as `prj-` and `sa-` repeat what the API path or the email domain already states, and use up part of the 30-character limit.
- One-letter environment codes (`b`, `c`, `p`, `n`, `d`) need a legend.

Its random suffix does make project IDs harder to guess. That matters less here, where the structure of the names is public anyway.

**No convention, naming each resource as it is created.** Not chosen because project IDs and bucket names cannot be corrected afterwards.

## Consequences

- A name can be written down before the resource exists, and committed code shows only `var.prefix` plus fixed segments.
- The resource type is not visible in the name. Output that mixes resource types has to show the type some other way.
- Uniqueness of project IDs and bucket names depends on the prefix. If a name is already taken globally, we change the purpose or the counter.
- The prefix is fixed once the first project exists; changing it means recreating every project and bucket.
- The environments are simulated. `prod` marks the shared foundation or the second environment of a workload, not a production service level.
- The convention is enforced by review only. Nothing in CI checks names.
- We would revisit this if the organization gained a second tenant or team, which would need another segment.
