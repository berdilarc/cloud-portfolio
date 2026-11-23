resource "google_service_account" "cicd" {
  for_each = local.cicd_service_accounts

  project      = google_project.iac.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.iac]
}

resource "google_service_account_iam_member" "cicd_workload_identity" {
  for_each = local.cicd_service_accounts

  service_account_id = google_service_account.cicd[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.subject}"
}

resource "google_service_account_iam_member" "cicd_impersonation" {
  for_each = local.cicd_service_accounts

  service_account_id = google_service_account.stage[each.value.stage_account].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.cicd[each.key].member
}
