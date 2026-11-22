locals {
  ro_service_accounts = toset([
    for id, sa in local.stage_service_accounts : id if sa.mode == "ro"
  ])

  rw_service_accounts = toset([
    for id, sa in local.stage_service_accounts : id if sa.mode == "rw"
  ])

  local_plan_bindings = merge(
    {
      for pair in setproduct(local.ro_service_accounts, var.local_plan_principals) : "${pair[0]} ${pair[1]}" => {
        service_account = pair[0]
        member          = pair[1]
      }
    },
    {
      for sa in local.ro_service_accounts : "${sa} agent" => {
        service_account = sa
        member          = google_service_account.agent.member
      }
    },
  )

  local_apply_bindings = {
    for pair in setproduct(local.rw_service_accounts, var.local_apply_principals) : "${pair[0]} ${pair[1]}" => {
      service_account = pair[0]
      member          = pair[1]
    }
  }

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

resource "google_service_account" "stage" {
  for_each = local.stage_service_accounts

  project      = google_project.iac.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.iac]
}

resource "google_service_account_iam_member" "local_plan" {
  for_each = local.local_plan_bindings

  service_account_id = google_service_account.stage[each.value.service_account].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value.member
}

resource "google_service_account_iam_member" "local_apply" {
  for_each = local.local_apply_bindings

  service_account_id = google_service_account.stage[each.value.service_account].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value.member
}

resource "google_service_account" "agent" {
  project      = google_project.iac.project_id
  account_id   = "iac-agent"
  display_name = "IaC agent"
  description  = "Identity for coding agents. Has no roles of its own; runs terraform plan by impersonating the read-only stage accounts."

  depends_on = [google_project_service.iac]
}

resource "google_service_account_iam_member" "agent" {
  for_each = var.local_plan_principals

  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.key
}

resource "google_project_iam_member" "iac" {
  for_each = local.iac_project_bindings

  project = google_project.iac.project_id
  role    = each.value.role
  member  = google_service_account.stage[each.value.service_account].member
}

resource "google_project_iam_member" "iac_storage_viewer" {
  project = google_project.iac.project_id
  role    = google_organization_iam_custom_role.storage_viewer.name
  member  = google_service_account.stage["iac-org-ro"].member
}
