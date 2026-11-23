locals {
  org_roles = {
    "iac-org-rw" = [
      "roles/iam.organizationRoleAdmin",
      "roles/iam.securityAdmin",
      "roles/resourcemanager.projectCreator",
    ]
    "iac-org-ro" = [
      "roles/browser",
      "roles/iam.securityReviewer",
    ]
  }

  org_bindings = {
    for binding in flatten([
      for sa, roles in local.org_roles : [
        for role in roles : {
          service_account = sa
          role            = role
        }
      ]
    ]) : "${binding.service_account} ${binding.role}" => binding
  }
}

resource "google_organization_iam_custom_role" "storage_viewer" {
  role_id     = "storageViewer"
  org_id      = var.org_id
  title       = "Storage Viewer with IAM"
  description = "Read buckets, managed folders, and objects, plus bucket and managed folder IAM policies."
  permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.list",
    "storage.managedFolders.get",
    "storage.managedFolders.getIamPolicy",
    "storage.managedFolders.list",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_organization_iam_member" "stage" {
  for_each = local.org_bindings

  org_id = var.org_id
  role   = each.value.role
  member = google_service_account.stage[each.value.service_account].member
}
