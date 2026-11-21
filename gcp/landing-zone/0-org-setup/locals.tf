locals {
  iac_project_id            = "${var.prefix}-prod-iac-core-0"
  billing_export_project_id = "${var.prefix}-prod-billing-export-0"

  iac_buckets = toset([
    "org-state",
    "stage-state",
    "outputs",
  ])

  stages = {
    "0-org-setup" = {
      name      = "org setup"
      sa_prefix = "iac-org"
    }
    "2-networking" = {
      name      = "networking"
      sa_prefix = "iac-networking"
    }
    "2-project-factory" = {
      name      = "project factory"
      sa_prefix = "iac-pf"
    }
  }

  stage_modes = {
    rw = {
      access     = "read-write"
      command    = "apply"
      state_role = "roles/storage.objectUser"
    }
    ro = {
      access     = "read-only"
      command    = "plan"
      state_role = "roles/storage.objectViewer"
    }
  }

  stage_service_accounts = {
    for sa in flatten([
      for stage, stage_config in local.stages : [
        for mode, mode_config in local.stage_modes : {
          id           = "${stage_config.sa_prefix}-${mode}"
          stage        = stage
          mode         = mode
          display_name = "IaC ${stage_config.name} (${mode_config.access})"
          description  = "Runs terraform ${mode_config.command} for the ${stage} stage."
        }
      ]
    ]) : sa.id => sa
  }

  managed_folder_stages = toset([
    for stage in keys(local.stages) : stage if stage != "0-org-setup"
  ])

  iac_project_roles = {
    "iac-org-rw" = [
      "roles/iam.serviceAccountAdmin",
      "roles/iam.workloadIdentityPoolAdmin",
      "roles/resourcemanager.projectIamAdmin",
      "roles/serviceusage.serviceUsageAdmin",
      "roles/storage.admin",
    ]
    "iac-org-ro" = [
      "roles/iam.serviceAccountViewer",
      "roles/iam.workloadIdentityPoolViewer",
      "roles/serviceusage.serviceUsageViewer",
    ]
  }

  iac_project_bindings = {
    for binding in flatten([
      for sa, roles in local.iac_project_roles : [
        for role in roles : {
          service_account = sa
          role            = role
        }
      ]
    ]) : "${binding.service_account} ${binding.role}" => binding
  }
}
