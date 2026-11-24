locals {
  environment_folders = {
    dev  = "Development"
    prod = "Production"
  }
}

resource "google_folder" "networking" {
  display_name = "Networking"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "networking_environment" {
  for_each = local.environment_folders

  display_name = each.value
  parent       = google_folder.networking.name
}

resource "google_folder" "teams" {
  display_name = "Teams"
  parent       = "organizations/${var.org_id}"
}
