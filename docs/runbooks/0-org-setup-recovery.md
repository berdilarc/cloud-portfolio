# Recovery of 0-org-setup

CI/CD applies stage 0 as `iac-org-rw`. If a change deletes or disables that account, or removes one of its roles, CI/CD can no longer apply the fix. Find the matching case below, restore access, and then [bring the code back in line](#after-the-fix).

## Who does what

| Person | Roles | Does |
| --- | --- | --- |
| A member of `organization_admins` | Organization Administrator on the organization and Billing Account Administrator on the billing account, through the group | Grants and removes the temporary roles, and grants back lost organization, project, and billing account roles |
| The operator, who can be the same admin | The temporary roles of the case, and membership in `iac_operators` | Runs the gcloud and Terraform steps |

Organization Administrator includes `resourcemanager.organizations.setIamPolicy` and `resourcemanager.projects.setIamPolicy`, but no service account permissions. So the admin grants project-level roles, such as Service Account Admin on the IaC core project, and the operator works on the accounts with them. See [Resource Manager roles](https://docs.cloud.google.com/iam/docs/roles-permissions/resourcemanager#resourcemanager.organizationAdmin).

The admin grants a temporary project role with:

```sh
gcloud projects add-iam-policy-binding <prefix>-prod-iac-core-0 --member user:<name>@example.com --role roles/iam.serviceAccountAdmin
```

The admin removes it with `remove-iam-policy-binding` and the same flags once the case is fixed.

Until the fix is done, don't approve a stage 0 apply in CI/CD. Some cases get worse if Terraform runs before the fix.

## Cases

### `iac-org-rw` was deleted less than 30 days ago

Temporary role: Service Account Admin (`roles/iam.serviceAccountAdmin`) on the IaC core project. It includes `iam.serviceAccounts.undelete`.

[An undeleted account keeps its roles](https://docs.cloud.google.com/iam/docs/service-accounts-delete-undelete), because its identity doesn't change. A new account with the same name is a different identity. It doesn't get the old roles, and you can't undelete the old account until you delete the new one. So don't apply anything that would create `iac-org-rw` again.

Undeleting takes the account's numeric unique ID. Plan access reads it from the state:

```sh
terraform state show 'google_service_account.stage["iac-org-rw"]'
```

The `unique_id` attribute holds the ID. Bindings on other resources also show it, as `deleted:serviceAccount:iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com?uid=<unique-id>`. Then:

```sh
gcloud iam service-accounts undelete <unique-id>
```

### `iac-org-rw` was deleted more than 30 days ago

After 30 days, the account is removed for good, along with its roles. Terraform has to create it again with your own credentials:

1. The admin grants the operator the roles of `iac-org-rw` that the stage README lists under [IAM](../../gcp/landing-zone/0-org-setup/README.md#iam), Billing Account Administrator included.
2. The operator applies as described in [Running](../../gcp/landing-zone/0-org-setup/README.md#running), under applying with your own credentials. The apply creates the account and its bindings.
3. The admin removes the temporary roles.

### `iac-org-rw` is disabled

Temporary role: Service Account Admin on the IaC core project. It includes `iam.serviceAccounts.enable`.

```sh
gcloud iam service-accounts enable iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --project <prefix>-prod-iac-core-0
```

### `iac-org-rw` lost a role on a project, the organization, or the billing account

No temporary role is needed. The admin grants the role back:

```sh
gcloud projects add-iam-policy-binding <project-id> --member serviceAccount:iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --role <role>
gcloud organizations add-iam-policy-binding <org_id> --member serviceAccount:iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --role <role>
gcloud billing accounts add-iam-policy-binding <billing_account> --member serviceAccount:iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --role roles/billing.admin
```

The stage README lists the roles under [IAM](../../gcp/landing-zone/0-org-setup/README.md#iam).

### `iac-org-rw` works, but the CI/CD accounts or workload identity federation don't

For example, `iac-org-cicd-apply` lost Token Creator on `iac-org-rw`, or the workload identity provider was changed. `iac-org-rw` can still apply, so apply the fixed code with a [break-glass apply](0-org-setup-break-glass-apply.md) from a local checkout of the fix.

### A failed create left a resource tainted

For example, Terraform created a project but couldn't link its billing account. Terraform marks the resource tainted, so the next plan replaces it. To fix the cause and keep the resource, untaint it with a break-glass apply. Run `terraform untaint` in place of the plan and apply:

```sh
terraform untaint '<address>'
```

The next plan then changes the resource in place.

## After the fix

- Revert or fix the bad change in a pull request. Its plan should show only the fix, or no changes if a break-glass apply already applied it.
- The admin removes the temporary roles, and you check the IaC core project's policy:

```sh
gcloud projects get-iam-policy <prefix>-prod-iac-core-0
```
