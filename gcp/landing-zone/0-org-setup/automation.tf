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
