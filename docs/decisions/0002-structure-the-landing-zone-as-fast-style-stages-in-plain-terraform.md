# 0002. Structure the landing zone as FAST-style stages in plain Terraform

- Status: accepted
- Date: 2026-11-19

## Context

The organization needs a foundation that workload projects build on: a project for infrastructure as code, Terraform state, identities for automation, and CI/CD, followed by shared networking and a project factory. Until now a single root module held all of it, with one state and one pair of plan and apply service accounts.

Google publishes two references for such a foundation: the [enterprise foundations blueprint](https://docs.cloud.google.com/architecture/blueprints/security-foundations) and [Cloud Foundation Fabric FAST](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast). The question is which one to follow for the stage layout, identities, and CI/CD.

FAST splits the foundation into stages, each a separate root module with its own state and its own read-write and read-only service accounts. Its first stage, [`0-org-setup`](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/v60.0.0/fast/stages/0-org-setup), creates those accounts and state locations for every stage, and hands them to the later stages as generated providers and tfvars files. FAST builds everything from the Fabric modules, configured through YAML datasets.

The repository is a portfolio, so the code should show the Google Cloud resources and their IAM bindings directly.

## Decision

We will split the landing zone into stages that follow FAST's layout, names, and hand-off between stages, written as plain Terraform with `google_*` resources, without the Fabric modules or YAML factories. We follow FAST rather than the enterprise foundations blueprint because FAST gives each stage a read-write account for applies and a read-only account for plans, so pull request runs never hold write access.

Stages and features are added when they are needed, not as FAST's complete set.

## Alternatives considered

**Keep a single root module.** Not chosen because one state and one apply account would cover the whole foundation: every change would plan everything, and a compromised CI/CD run would hold every permission.

**Deploy FAST, or use the Fabric modules in our own layout.** Not chosen because the modules and YAML datasets put the resources and their bindings behind module interfaces, so the code would show configuration rather than Google Cloud resources.

**Follow the enterprise foundations blueprint.** Its implementation, [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation/tree/v7.0.0), also splits the foundation into stages with one service account each. Not chosen because that account runs both plans and applies ([pull request workflow](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v7.0.0/build/github-tf-pull-request.yaml), [apply workflow](https://github.com/terraform-google-modules/terraform-example-foundation/blob/v7.0.0/build/github-tf-apply.yaml)), so pull request plans would run with write access.

## Consequences

- Each stage holds only the permissions of its own accounts and keeps its own state.
- Readers who know FAST recognize the stage layout, account names, and hand-off between stages.
- Every resource and binding is visible in the stage code, at the cost of writing and maintaining what the Fabric modules would provide.
