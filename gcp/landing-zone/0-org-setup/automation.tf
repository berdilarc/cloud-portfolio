resource "google_storage_bucket" "iac" {
  for_each = local.iac_buckets

  name                        = "${google_project.iac.project_id}-${each.key}"
  project                     = google_project.iac.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions         = 5
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.iac]
}

resource "google_service_account" "stage" {
  for_each = local.stage_service_accounts

  project      = google_project.iac.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.iac]
}

resource "google_storage_managed_folder" "stage_state" {
  for_each = local.managed_folder_stages

  bucket = google_storage_bucket.iac["stage-state"].name
  name   = "${each.key}/"
}

resource "google_storage_managed_folder_iam_member" "stage_state" {
  for_each = {
    for id, sa in local.stage_service_accounts : id => sa if contains(local.managed_folder_stages, sa.stage)
  }

  bucket         = google_storage_managed_folder.stage_state[each.value.stage].bucket
  managed_folder = google_storage_managed_folder.stage_state[each.value.stage].name
  role           = local.stage_modes[each.value.mode].state_role
  member         = google_service_account.stage[each.key].member
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
