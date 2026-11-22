resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.iac.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub"
  description               = "Identities from GitHub Actions."

  depends_on = [google_project_service.iac]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  project                            = google_project.iac.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"
  description                        = "OIDC tokens from GitHub Actions, limited to one repository."

  attribute_condition = "assertion.repository_id == '${var.github_repository_id}' && assertion.repository_owner_id == '${var.github_repository_owner_id}'"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "cicd_workload_identity" {
  for_each = local.cicd_service_accounts

  service_account_id = google_service_account.cicd[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.subject}"
}
