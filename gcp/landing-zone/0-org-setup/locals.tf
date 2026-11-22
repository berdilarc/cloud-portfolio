locals {
  stages = {
    "0-org-setup" = {
      name        = "org setup"
      enable_cicd = true
      sa_prefix   = "iac-org"
    }
    "2-networking" = {
      name        = "networking"
      enable_cicd = false
      sa_prefix   = "iac-networking"
    }
    "2-project-factory" = {
      name        = "project factory"
      enable_cicd = false
      sa_prefix   = "iac-pf"
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

  cicd_modes = {
    ro = {
      access     = "read-only"
      plans_role = null
      stage_mode = "ro"
      trigger    = "on pull requests"
    }
    merge = {
      access     = "merge plan"
      plans_role = "roles/storage.objectCreator"
      stage_mode = "ro"
      trigger    = "on merges to main"
    }
    rw = {
      access     = "read-write"
      plans_role = "roles/storage.objectViewer"
      stage_mode = "rw"
      trigger    = "after environment approval"
    }
  }

  cicd_service_accounts = {
    for sa in flatten([
      for stage, stage_config in local.stages : [
        for mode, mode_config in local.cicd_modes : {
          id            = "${stage_config.sa_prefix}-cicd-${mode}"
          stage         = stage
          mode          = mode
          stage_account = "${stage_config.sa_prefix}-${mode_config.stage_mode}"
          display_name  = "IaC ${stage_config.name} CI/CD (${mode_config.access})"
          description   = "Runs terraform ${local.stage_modes[mode_config.stage_mode].command} for the ${stage} stage ${mode_config.trigger}, as ${stage_config.sa_prefix}-${mode_config.stage_mode}."
          subject = {
            ro    = "repo:${var.github_repository}:pull_request"
            merge = "repo:${var.github_repository}:ref:refs/heads/main"
            rw    = "repo:${var.github_repository}:environment:${stage}"
          }[mode]
        }
      ] if stage_config.enable_cicd
    ]) : sa.id => sa
  }

  storage_buckets = merge(
    { for id, bucket in google_storage_bucket.iac : id => bucket.name },
    { "cicd-plans" = google_storage_bucket.cicd_plans.name },
  )
}
