locals {
  iac_project_id            = "${var.prefix}-prod-iac-core-0"
  billing_export_project_id = "${var.prefix}-prod-billing-export-0"
  audit_logs_project_id     = "${var.prefix}-prod-audit-logs-0"

  basic_project_roles = {
    "iac-org-rw" = "roles/owner"
    "iac-org-ro" = "roles/viewer"
  }
}

resource "google_project" "iac" {
  name            = local.iac_project_id
  project_id      = local.iac_project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  depends_on = [
    google_logging_organization_settings.default,
    google_org_policy_policy.enforced,
  ]
}

resource "google_project_service" "iac" {
  for_each = var.iac_project_services

  project            = google_project.iac.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project" "billing_export" {
  name            = local.billing_export_project_id
  project_id      = local.billing_export_project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  depends_on = [
    google_logging_organization_settings.default,
    google_org_policy_policy.enforced,
  ]
}

resource "google_project_iam_member" "billing_export" {
  for_each = local.basic_project_roles

  project = google_project.billing_export.project_id
  role    = each.value
  member  = google_service_account.stage[each.key].member
}

resource "google_project" "audit_logs" {
  name            = local.audit_logs_project_id
  project_id      = local.audit_logs_project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  depends_on = [
    google_logging_organization_settings.default,
    google_org_policy_policy.enforced,
  ]
}

resource "google_project_iam_member" "audit_logs" {
  for_each = local.basic_project_roles

  project = google_project.audit_logs.project_id
  role    = each.value
  member  = google_service_account.stage[each.key].member
}

resource "google_project_service" "audit_logs" {
  for_each = var.audit_logs_project_services

  project            = google_project.audit_logs.project_id
  service            = each.key
  disable_on_destroy = false
}
