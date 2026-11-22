resource "google_service_account" "stage" {
  for_each = local.stage_service_accounts

  project      = google_project.iac.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.iac]
}

resource "google_service_account" "cicd" {
  for_each = local.cicd_service_accounts

  project      = google_project.iac.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.iac]
}

resource "google_project_iam_member" "iac" {
  for_each = local.iac_project_bindings

  project = google_project.iac.project_id
  role    = each.value.role
  member  = google_service_account.stage[each.value.service_account].member
}

resource "google_project_iam_member" "iac_storage_viewer" {
  project = google_project.iac.project_id
  role    = google_organization_iam_custom_role.storage_viewer.name
  member  = google_service_account.stage["iac-org-ro"].member
}

resource "google_service_account_iam_member" "local_plan" {
  for_each = local.local_plan_bindings

  service_account_id = google_service_account.stage[each.value.service_account].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value.member
}

resource "google_service_account_iam_member" "cicd_impersonation" {
  for_each = local.cicd_service_accounts

  service_account_id = google_service_account.stage[each.value.stage_account].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_service_account.cicd[each.key].member
}
