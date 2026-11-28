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
    "iac-pf-ro" = [
      "roles/compute.viewer",
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

  networking_folder_custom_roles = {
    "iac-pf-rw" = "service_project_network_admin"
    "iac-pf-ro" = "project_iam_viewer"
  }

  shared_vpc_grantable_roles = [
    "roles/composer.sharedVpcAgent",
    "roles/compute.networkUser",
    "roles/container.hostServiceAgentUser",
    "roles/vpcaccess.user",
  ]

  teams_folder_roles = {
    "iac-pf-rw" = [
      "roles/owner",
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/resourcemanager.tagUser",
    ]
    "iac-pf-ro" = [
      "roles/resourcemanager.folderViewer",
      "roles/resourcemanager.tagViewer",
      "roles/viewer",
    ]
  }

  teams_folder_bindings = {
    for binding in flatten([
      for sa, roles in local.teams_folder_roles : [
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

resource "google_folder_iam_member" "networking_custom" {
  for_each = local.networking_folder_custom_roles

  folder = google_folder.networking.name
  role   = google_organization_iam_custom_role.stage[each.value].name
  member = google_service_account.stage[each.key].member
}

# The project factory can grant service projects the Shared VPC roles they
# need on the host projects, and no other role.
resource "google_folder_iam_member" "networking_project_iam_admin" {
  folder = google_folder.networking.name
  role   = "roles/resourcemanager.projectIamAdmin"
  member = google_service_account.stage["iac-pf-rw"].member

  condition {
    title      = "Shared VPC grants only"
    expression = "api.getAttribute('iam.googleapis.com/modifiedGrantsByRole', []).hasOnly(${jsonencode(local.shared_vpc_grantable_roles)})"
  }
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

resource "google_folder_iam_member" "teams" {
  for_each = local.teams_folder_bindings

  folder = google_folder.teams.name
  role   = each.value.role
  member = google_service_account.stage[each.value.service_account].member
}

resource "google_folder_iam_member" "teams_custom" {
  folder = google_folder.teams.name
  role   = google_organization_iam_custom_role.stage["service_project_network_admin"].name
  member = google_service_account.stage["iac-pf-rw"].member
}
