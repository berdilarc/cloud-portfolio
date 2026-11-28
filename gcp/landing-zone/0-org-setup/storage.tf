locals {
  iac_buckets = toset([
    "org-state",
    "stage-state",
    "outputs",
  ])

  managed_folder_stages = toset([
    for stage in keys(local.stages) : stage if stage != "0-org-setup"
  ])

  cicd_stages = toset([
    for stage, stage_config in local.stages : stage if stage_config.enable_cicd
  ])

  tfvars_stages = toset([
    "2-networking",
  ])
}

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

resource "google_storage_bucket_iam_member" "outputs_cicd" {
  for_each = local.cicd_service_accounts

  bucket = google_storage_bucket.iac["outputs"].name
  role   = "roles/storage.objectViewer"
  member = google_service_account.cicd[each.key].member
}

resource "google_storage_bucket_iam_member" "outputs_tfvars" {
  for_each = {
    for id, sa in local.stage_service_accounts : id => sa if contains(local.tfvars_stages, sa.stage)
  }

  bucket = google_storage_bucket.iac["outputs"].name
  role   = local.stage_modes[each.value.mode].object_role
  member = google_service_account.stage[each.key].member

  condition {
    title       = "${each.value.stage} tfvars file"
    description = "Only the ${each.value.stage} stage's own tfvars file."
    expression  = "resource.name == \"projects/_/buckets/${google_storage_bucket.iac["outputs"].name}/objects/tfvars/${each.value.stage}.auto.tfvars.json\""
  }
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
  role           = local.stage_modes[each.value.mode].object_role
  member         = google_service_account.stage[each.key].member
}

resource "google_storage_bucket" "cicd_plans" {
  name                        = "${google_project.iac.project_id}-cicd-plans"
  project                     = google_project.iac.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.iac]
}

resource "google_storage_managed_folder" "cicd_plans" {
  for_each = local.cicd_stages

  bucket        = google_storage_bucket.cicd_plans.name
  name          = "${each.key}/"
  force_destroy = true
}

resource "google_storage_managed_folder_iam_member" "cicd_plans" {
  for_each = {
    for id, sa in local.cicd_service_accounts : id => sa if local.cicd_modes[sa.mode].plans_role != null
  }

  bucket         = google_storage_managed_folder.cicd_plans[each.value.stage].bucket
  managed_folder = google_storage_managed_folder.cicd_plans[each.value.stage].name
  role           = local.cicd_modes[each.value.mode].plans_role
  member         = google_service_account.cicd[each.key].member
}
