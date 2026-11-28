locals {
  teams = {
    platform = "Platform"
  }

  environment_folders = {
    dev  = "Development"
    prod = "Production"
  }

  team_environment_folders = {
    for pair in setproduct(keys(local.teams), keys(local.environment_folders)) : "${pair[0]}/${pair[1]}" => {
      team        = pair[0]
      environment = pair[1]
    }
  }
}

resource "google_folder" "team" {
  for_each = local.teams

  display_name = each.value
  parent       = var.folder_ids["teams"]
}

resource "google_folder" "team_environment" {
  for_each = local.team_environment_folders

  display_name = local.environment_folders[each.value.environment]
  parent       = google_folder.team[each.value.team].name
}
