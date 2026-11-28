locals {
  projects = {
    dev-web = {
      folder     = "platform/dev"
      project_id = "${var.prefix}-dev-web-0"
      services   = ["compute.googleapis.com"]
    }
  }

  project_services = {
    for pair in flatten([
      for key, project in local.projects : [
        for service in project.services : {
          project = key
          service = service
        }
      ]
    ]) : "${pair.project} ${pair.service}" => pair
  }
}

resource "google_project" "workload" {
  for_each = local.projects

  name            = each.value.project_id
  project_id      = each.value.project_id
  folder_id       = google_folder.team_environment[each.value.folder].name
  billing_account = var.billing_account
}

resource "google_project_service" "workload" {
  for_each = local.project_services

  project            = google_project.workload[each.value.project].project_id
  service            = each.value.service
  disable_on_destroy = false
}
