locals {
  host_projects = {
    hub = {
      folder     = "networking"
      project_id = "${var.prefix}-prod-net-core-0"
    }
    dev = {
      folder     = "networking/dev"
      project_id = "${var.prefix}-dev-net-spoke-0"
    }
    prod = {
      folder     = "networking/prod"
      project_id = "${var.prefix}-prod-net-spoke-0"
    }
  }
}

# The compute.skipDefaultNetworkCreation org policy stops the default network.
#trivy:ignore:AVD-GCP-0010
resource "google_project" "host" {
  for_each = local.host_projects

  name            = each.value.project_id
  project_id      = each.value.project_id
  folder_id       = var.folder_ids[each.value.folder]
  billing_account = var.billing_account
}
