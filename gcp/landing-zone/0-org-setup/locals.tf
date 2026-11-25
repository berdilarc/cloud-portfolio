locals {
  org_name = "organizations/${var.org_id}"

  stages = {
    "0-org-setup" = {
      name        = "org setup"
      enable_cicd = true
      sa_prefix   = "iac-org"
    }
    "2-networking" = {
      name        = "networking"
      enable_cicd = true
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
    pr = {
      purpose    = "pull request plan"
      plans_role = null
      stage_mode = "ro"
      trigger    = "on pull requests"
    }
    merge = {
      purpose    = "merge plan"
      plans_role = "roles/storage.objectCreator"
      stage_mode = "ro"
      trigger    = "on merges to main"
    }
    apply = {
      purpose    = "apply"
      plans_role = "roles/storage.objectViewer"
      stage_mode = "rw"
      trigger    = "after environment approval"
    }
  }

  github_subject_prefix = format(
    "repo:%s@%s/%s@%s",
    split("/", var.github_repository)[0],
    var.github_repository_owner_id,
    split("/", var.github_repository)[1],
    var.github_repository_id,
  )

  cicd_service_accounts = {
    for sa in flatten([
      for stage, stage_config in local.stages : [
        for mode, mode_config in local.cicd_modes : {
          id            = "${stage_config.sa_prefix}-cicd-${mode}"
          stage         = stage
          mode          = mode
          stage_account = "${stage_config.sa_prefix}-${mode_config.stage_mode}"
          display_name  = "IaC ${stage_config.name} CI/CD (${mode_config.purpose})"
          description   = "Runs terraform ${local.stage_modes[mode_config.stage_mode].command} for the ${stage} stage ${mode_config.trigger}, as ${stage_config.sa_prefix}-${mode_config.stage_mode}."
          subject = {
            pr    = "${local.github_subject_prefix}:pull_request"
            merge = "${local.github_subject_prefix}:ref:refs/heads/main"
            apply = "${local.github_subject_prefix}:environment:${stage}"
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
