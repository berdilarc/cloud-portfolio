locals {
  environment_folders = {
    dev  = "Development"
    prod = "Production"
  }

  networking_folder_roles = {
    "iac-networking-rw" = [
      "roles/compute.xpnAdmin",
      "roles/logging.admin",
      "roles/owner",
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/resourcemanager.tagUser",
    ]
    "iac-networking-ro" = [
      "roles/resourcemanager.folderViewer",
      "roles/resourcemanager.tagViewer",
      "roles/viewer",
    ]
  }

  networking_folder_bindings = {
    for binding in flatten([
      for sa, roles in local.networking_folder_roles : [
        for role in roles : {
          service_account = sa
          role            = role
        }
      ]
    ]) : "${binding.service_account} ${binding.role}" => binding
  }
}

resource "google_folder" "networking" {
  display_name = "Networking"
  parent       = local.org_name

  depends_on = [google_logging_organization_settings.default]
}

resource "google_folder_iam_member" "networking" {
  for_each = local.networking_folder_bindings

  folder = google_folder.networking.name
  role   = each.value.role
  member = google_service_account.stage[each.value.service_account].member
}

resource "google_folder" "networking_environment" {
  for_each = local.environment_folders

  display_name = each.value
  parent       = google_folder.networking.name
}

resource "google_folder" "teams" {
  display_name = "Teams"
  parent       = local.org_name

  depends_on = [google_logging_organization_settings.default]
}
