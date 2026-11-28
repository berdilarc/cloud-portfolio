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

resource "google_project" "host" {
  for_each = local.host_projects

  name            = each.value.project_id
  project_id      = each.value.project_id
  folder_id       = var.folder_ids[each.value.folder]
  billing_account = var.billing_account
}

resource "google_project_service" "host" {
  for_each = {
    for pair in setproduct(keys(local.host_projects), var.host_project_services) :
    "${pair[0]} ${pair[1]}" => {
      host    = pair[0]
      service = pair[1]
    }
  }

  project            = google_project.host[each.value.host].project_id
  service            = each.value.service
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  for_each = google_project.host

  project = each.value.project_id

  depends_on = [google_project_service.host]
}
