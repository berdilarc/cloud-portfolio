locals {
  # Data Access logs for the IAM API also cover the Service Account Credentials
  # API, so they record every impersonation of the stage service accounts.
  iac_data_access_services = toset([
    "iam.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_organization_iam_audit_config" "sts" {
  org_id  = var.org_id
  service = "sts.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

resource "google_project_iam_audit_config" "iac" {
  for_each = local.iac_data_access_services

  project = google_project.iac.project_id
  service = each.key

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
