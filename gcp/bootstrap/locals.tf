locals {
  iac_service_accounts = {
    "iac-foundation-ro" = {
      display_name = "IaC foundation (plan)"
      description  = "Runs terraform plan for the foundation stack on pull requests."
      state_role   = "roles/storage.objectViewer"
    }
    "iac-foundation-rw" = {
      display_name = "IaC foundation (apply)"
      description  = "Runs terraform apply for the foundation stack after merge."
      state_role   = "roles/storage.objectUser"
    }
  }
}
