locals {
  # Data Access logs for the IAM API also cover the Service Account Credentials
  # API, so they record every impersonation of the stage service accounts.
  iac_data_access_services = toset([
    "iam.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])

  log_retention_days = 30

  log_sink_filters = {
    "audit-logs" = join(" OR ", [
      "log_id(\"cloudaudit.googleapis.com/activity\")",
      "log_id(\"cloudaudit.googleapis.com/system_event\")",
      "log_id(\"cloudaudit.googleapis.com/policy\")",
      "log_id(\"cloudaudit.googleapis.com/access_transparency\")",
    ])
    "iam" = join(" OR ", [
      "protoPayload.serviceName=\"iam.googleapis.com\"",
      "protoPayload.serviceName=\"iamcredentials.googleapis.com\"",
      "protoPayload.serviceName=\"sts.googleapis.com\"",
    ])
  }
}

resource "google_logging_organization_settings" "default" {
  organization     = var.org_id
  storage_location = var.region
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

resource "google_logging_project_bucket_config" "audit_logs" {
  for_each = local.log_sink_filters

  project          = google_project.audit_logs.project_id
  location         = var.region
  bucket_id        = each.key
  retention_days   = local.log_retention_days
  enable_analytics = true

  depends_on = [google_project_service.audit_logs]
}

resource "google_logging_organization_sink" "log_bucket" {
  for_each = local.log_sink_filters

  name             = each.key
  org_id           = var.org_id
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.audit_logs[each.key].id}"
  filter           = each.value
  include_children = true
}

# All sinks of the organization share one writer identity, so each binding is
# limited to its sink's bucket.
resource "google_project_iam_member" "log_sink" {
  for_each = local.log_sink_filters

  project = google_project.audit_logs.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.log_bucket[each.key].writer_identity

  condition {
    title      = "${each.key} log bucket"
    expression = "resource.name.endsWith(\"locations/${var.region}/buckets/${each.key}\")"
  }
}

resource "google_bigquery_dataset" "audit_logs" {
  project                         = google_project.audit_logs.project_id
  dataset_id                      = "audit_logs"
  location                        = var.region
  default_partition_expiration_ms = local.log_retention_days * 24 * 60 * 60 * 1000

  depends_on = [google_project_service.audit_logs]
}

resource "google_logging_organization_sink" "bigquery" {
  name             = "audit-logs-bigquery"
  org_id           = var.org_id
  destination      = "bigquery.googleapis.com/${google_bigquery_dataset.audit_logs.id}"
  filter           = local.log_sink_filters["audit-logs"]
  include_children = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "log_sink" {
  project    = google_bigquery_dataset.audit_logs.project
  dataset_id = google_bigquery_dataset.audit_logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_organization_sink.bigquery.writer_identity
}
