locals {
  provider_files = {
    for id, sa in local.stage_service_accounts : (sa.mode == "rw" ? sa.stage : "${sa.stage}-ro") => {
      bucket          = google_storage_bucket.iac[sa.stage == "0-org-setup" ? "org-state" : "stage-state"].name
      prefix          = sa.stage == "0-org-setup" ? null : sa.stage
      service_account = google_service_account.stage[id].email
    }
  }

  tfvars_files = {
    "0-org-setup" = jsonencode({
      custom_roles = { for key, role in google_organization_iam_custom_role.stage : key => role.name }
      folder_ids = merge(
        {
          "networking" = google_folder.networking.name
          "teams"      = google_folder.teams.name
        },
        { for key, folder in google_folder.networking_environment : "networking/${key}" => folder.name },
      )
      project_ids = {
        "audit-logs"     = google_project.audit_logs.project_id
        "billing-export" = google_project.billing_export.project_id
        "iac-core"       = google_project.iac.project_id
      }
      service_accounts           = { for id, sa in google_service_account.stage : id => sa.email }
      storage_buckets            = local.storage_buckets
      tag_values                 = { "firewall/http-server" = google_tags_tag_value.firewall_http_server.id }
      workload_identity_provider = google_iam_workload_identity_pool_provider.github_actions.name
    })
  }
}

resource "google_storage_bucket_object" "providers" {
  for_each = local.provider_files

  name    = "providers/${each.key}-providers.tf"
  bucket  = google_storage_bucket.iac["outputs"].name
  content = templatefile("${path.module}/templates/providers.tftpl", each.value)
}

resource "google_storage_bucket_object" "tfvars" {
  for_each = local.tfvars_files

  name    = "tfvars/${each.key}.auto.tfvars.json"
  bucket  = google_storage_bucket.iac["outputs"].name
  content = each.value
}
