locals {
  group_org_roles = {
    organization_admins = [
      "roles/advisorynotifications.viewer",
      "roles/resourcemanager.organizationAdmin",
    ]
    security_reviewers = [
      "roles/iam.securityReviewer",
    ]
  }

  group_billing_account_roles = {
    billing_viewers = [
      "roles/billing.viewer",
    ]
    organization_admins = [
      "roles/billing.admin",
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
