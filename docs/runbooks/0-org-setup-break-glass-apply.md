# Break-glass apply of 0-org-setup

CI/CD applies stage 0, and no person can impersonate its read-write account `iac-org-rw`. Use this runbook only when CI/CD can't apply a change the stage needs, for example when a broken change locks out the CI/CD accounts. If `iac-org-rw` itself is broken, see [Recovery](0-org-setup-recovery.md) first.

No person holds a standing role on the IaC core project. A member of the `organization_admins` group grants the temporary role below and removes it afterwards. The person who runs the apply can be the same admin or someone else.

## Grant access

The admin grants you Service Account Admin (`roles/iam.serviceAccountAdmin`) on the IaC core project. Organization Administrator includes `resourcemanager.projects.setIamPolicy`, so the admin can grant it without a role on the project. See [Resource Manager roles](https://docs.cloud.google.com/iam/docs/roles-permissions/resourcemanager#resourcemanager.organizationAdmin).

```sh
gcloud projects add-iam-policy-binding <prefix>-prod-iac-core-0 --member user:<name>@example.com --role roles/iam.serviceAccountAdmin
```

Service Account Admin includes `iam.serviceAccounts.setIamPolicy`, which lets you grant yourself Service Account Token Creator on `iac-org-rw`. See [IAM roles and permissions](https://docs.cloud.google.com/iam/docs/roles-permissions/iam#iam.serviceAccountAdmin).

```sh
gcloud iam service-accounts add-iam-policy-binding iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --member user:<name>@example.com --role roles/iam.serviceAccountTokenCreator --project <prefix>-prod-iac-core-0
```

The grants [typically take 2 minutes to take effect, potentially 7 minutes or longer](https://docs.cloud.google.com/iam/docs/access-change-propagation).

## Apply

In the stage directory, replace the read-only providers file with the read-write one, since only one of them can be in the directory at a time. Download it as `iac-org-rw`, which can read the `outputs` bucket:

```sh
rm 0-org-setup-ro-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/providers/0-org-setup-providers.tf . --impersonate-service-account iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

Then switch back:

```sh
rm tfplan 0-org-setup-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/providers/0-org-setup-ro-providers.tf . --impersonate-service-account iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init -reconfigure
```

## Remove access

The stage manages its bindings with non-authoritative `google_service_account_iam_member` resources, so an apply doesn't remove your grant. Remove it yourself:

```sh
gcloud iam service-accounts remove-iam-policy-binding iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --member user:<name>@example.com --role roles/iam.serviceAccountTokenCreator --project <prefix>-prod-iac-core-0
```

Then check that only the CI/CD apply account `iac-org-cicd-apply` still holds Service Account Token Creator on `iac-org-rw`:

```sh
gcloud iam service-accounts get-iam-policy iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
```

Finally, the admin removes Service Account Admin:

```sh
gcloud projects remove-iam-policy-binding <prefix>-prod-iac-core-0 --member user:<name>@example.com --role roles/iam.serviceAccountAdmin
```
