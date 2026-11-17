resource "google_storage_bucket" "tf_state" {
  name                        = "${var.project_id}-tf-state"
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
}

resource "google_project_service" "enabled" {
  for_each = var.services

  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "iac" {
  for_each = local.iac_service_accounts

  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.enabled]
}

resource "google_storage_bucket_iam_member" "tf_state" {
  for_each = local.iac_service_accounts

  bucket = google_storage_bucket.tf_state.name
  role   = each.value.state_role
  member = google_service_account.iac[each.key].member
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub"
  description               = "Identities from GitHub Actions."

  depends_on = [google_project_service.enabled]
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
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

resource "google_service_account_iam_member" "github_actions" {
  for_each = local.iac_service_accounts

  service_account_id = google_service_account.iac[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${each.value.oidc_subject}"
}
