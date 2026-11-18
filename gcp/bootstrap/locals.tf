locals {
  iac_service_accounts = {
    "iac-foundation-ro" = {
      display_name = "IaC foundation (plan)"
      description  = "Runs terraform plan for the foundation stack on pull requests."
      oidc_subject = "repo:${var.github_repository}:pull_request"

      state_role = "roles/storage.objectViewer"
      org_roles = [
        "roles/resourcemanager.folderViewer",
      ]
    }

    "iac-foundation-rw" = {
      display_name = "IaC foundation (apply)"
      description  = "Runs terraform apply for the foundation stack after merge."
      oidc_subject = "repo:${var.github_repository}:environment:${var.github_apply_environment}"

      state_role = "roles/storage.objectUser"
      org_roles = [
        "roles/resourcemanager.folderCreator",
      ]
    }
  }

  iac_org_roles = {
    for pair in flatten([
      for id, sa in local.iac_service_accounts : [
        for role in sa.org_roles : {
          service_account = id
          role            = role
        }
      ]
    ]) : "${pair.service_account} ${pair.role}" => pair
  }
}
