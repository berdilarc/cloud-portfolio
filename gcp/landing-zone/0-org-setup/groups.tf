locals {
  group_org_roles = {
    auditors = [
      "roles/iam.securityReviewer",
    ]
    organization_admins = [
      "roles/advisorynotifications.viewer",
      "roles/resourcemanager.organizationAdmin",
    ]
  }

  group_billing_account_roles = {
    auditors = [
      "roles/billing.viewer",
    ]
    organization_admins = [
      "roles/billing.admin",
    ]
  }

  group_audit_logs_project_roles = {
    auditors = [
      "roles/bigquery.dataViewer",
      "roles/bigquery.jobUser",
      "roles/logging.privateLogViewer",
    ]
  }

  group_org_bindings = {
    for binding in flatten([
      for group, roles in local.group_org_roles : [
        for role in roles : {
          group = group
          role  = role
        }
      ]
    ]) : "${binding.group} ${binding.role}" => binding
  }

  group_billing_account_bindings = {
    for binding in flatten([
      for group, roles in local.group_billing_account_roles : [
        for role in roles : {
          group = group
          role  = role
        }
      ]
    ]) : "${binding.group} ${binding.role}" => binding
  }

  group_audit_logs_project_bindings = {
    for binding in flatten([
      for group, roles in local.group_audit_logs_project_roles : [
        for role in roles : {
          group = group
          role  = role
        }
      ]
    ]) : "${binding.group} ${binding.role}" => binding
  }
}

resource "google_organization_iam_member" "group" {
  for_each = local.group_org_bindings

  org_id = var.org_id
  role   = each.value.role
  member = "group:${var.groups[each.value.group]}"
}

resource "google_billing_account_iam_member" "group" {
  for_each = local.group_billing_account_bindings

  billing_account_id = var.billing_account
  role               = each.value.role
  member             = "group:${var.groups[each.value.group]}"
}

resource "google_project_iam_member" "group_audit_logs" {
  for_each = local.group_audit_logs_project_bindings

  project = google_project.audit_logs.project_id
  role    = each.value.role
  member  = "group:${var.groups[each.value.group]}"
}
