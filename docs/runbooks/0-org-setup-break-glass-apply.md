# Break-glass apply of 0-org-setup

CI/CD applies stage 0, and no person can impersonate its read-write account `iac-org-rw`. Use this runbook only when CI/CD can't apply a change the stage needs, for example when a broken change locks out the CI/CD accounts.

## Prerequisites

- Service Account Admin (`roles/iam.serviceAccountAdmin`) on the IaC core project. It includes `iam.serviceAccounts.setIamPolicy`, which lets you grant yourself access to `iac-org-rw`. See [IAM roles and permissions](https://docs.cloud.google.com/iam/docs/roles-permissions/iam#iam.serviceAccountAdmin).
- Read access to the `config` bucket, to download the providers file.

## Grant access

Grant yourself Service Account Token Creator on `iac-org-rw`:

```sh
gcloud iam service-accounts add-iam-policy-binding iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --member user:<name>@example.com --role roles/iam.serviceAccountTokenCreator
```

The grant [typically takes 2 minutes to take effect, potentially 7 minutes or longer](https://docs.cloud.google.com/iam/docs/access-change-propagation).

## Apply

In the stage directory, replace the read-only providers file with the read-write one, since only one of them can be in the directory at a time:

```sh
rm 0-org-setup-ro-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-providers.tf .
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

Then switch back:

```sh
rm tfplan 0-org-setup-providers.tf
gcloud storage cp gs://<prefix>-prod-iac-core-0-config/providers/0-org-setup-ro-providers.tf .
terraform init -reconfigure
```

## Remove access

The stage manages its bindings with non-authoritative `google_service_account_iam_member` resources, so an apply doesn't remove your grant. Remove it yourself:

```sh
gcloud iam service-accounts remove-iam-policy-binding iac-org-rw@<prefix>-prod-iac-core-0.iam.gserviceaccount.com --member user:<name>@example.com --role roles/iam.serviceAccountTokenCreator
```
