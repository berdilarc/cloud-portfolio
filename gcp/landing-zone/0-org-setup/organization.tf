locals {
  custom_roles = {
    organization_admin_viewer = {
      role_id     = "organizationAdminViewer"
      title       = "Organization Admin Viewer"
      description = "Read the organization, folders, and projects with their IAM policies, plus org policies, Essential Contacts, logging settings, and bucket IAM policies."
      permissions = [
        "essentialcontacts.contacts.get",
        "essentialcontacts.contacts.list",
        "logging.settings.get",
        "orgpolicy.constraints.list",
        "orgpolicy.policies.list",
        "orgpolicy.policy.get",
        "resourcemanager.folders.get",
        "resourcemanager.folders.getIamPolicy",
        "resourcemanager.folders.list",
        "resourcemanager.organizations.get",
        "resourcemanager.organizations.getIamPolicy",
        "resourcemanager.projects.get",
        "resourcemanager.projects.getIamPolicy",
        "resourcemanager.projects.list",
        "storage.buckets.getIamPolicy",
      ]
    }
    storage_viewer = {
      role_id     = "storageViewer"
      title       = "Storage Viewer with IAM"
      description = "Read buckets, managed folders, and objects with their IAM policies, plus bucket tags, object insights, and multipart uploads."
      permissions = [
        "storage.buckets.get",
        "storage.buckets.getIamPolicy",
        "storage.buckets.getObjectInsights",
        "storage.buckets.list",
        "storage.buckets.listEffectiveTags",
        "storage.buckets.listTagBindings",
        "storage.managedFolders.get",
        "storage.managedFolders.getIamPolicy",
        "storage.managedFolders.list",
        "storage.multipartUploads.list",
        "storage.multipartUploads.listParts",
        "storage.objects.get",
        "storage.objects.getIamPolicy",
        "storage.objects.list",
      ]
    }
    tag_viewer = {
      role_id     = "tagViewer"
      title       = "Tag Viewer with IAM"
      description = "Read tag keys and tag values with their IAM policies, and list tag holds."
      permissions = [
        "resourcemanager.tagHolds.list",
        "resourcemanager.tagKeys.get",
        "resourcemanager.tagKeys.getIamPolicy",
        "resourcemanager.tagKeys.list",
        "resourcemanager.tagValues.get",
        "resourcemanager.tagValues.getIamPolicy",
        "resourcemanager.tagValues.list",
      ]
    }
  }

  org_roles = {
    "iac-org-rw" = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/cloudasset.viewer",
      "roles/essentialcontacts.admin",
      "roles/iam.organizationRoleAdmin",
      "roles/iam.workforcePoolAdmin",
      "roles/logging.admin",
      "roles/orgpolicy.policyAdmin",
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.organizationAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/resourcemanager.projectMover",
      "roles/resourcemanager.tagAdmin",
      "roles/resourcemanager.tagUser",
    ]
    "iac-org-ro" = [
      "roles/cloudasset.viewer",
      "roles/essentialcontacts.viewer",
      "roles/iam.organizationRoleViewer",
      "roles/iam.workforcePoolViewer",
      "roles/logging.viewer",
      "roles/orgpolicy.policyViewer",
      "roles/resourcemanager.folderViewer",
      "roles/resourcemanager.tagViewer",
      "roles/serviceusage.serviceUsageViewer",
    ]
  }

  org_custom_viewer_roles = toset(["organization_admin_viewer", "tag_viewer"])

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

resource "google_organization_iam_custom_role" "stage" {
  for_each = local.custom_roles

  role_id     = each.value.role_id
  org_id      = var.org_id
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
}

moved {
  from = google_organization_iam_custom_role.storage_viewer
  to   = google_organization_iam_custom_role.stage["storage_viewer"]
}

resource "google_organization_iam_member" "stage" {
  for_each = local.org_bindings

  org_id = var.org_id
  role   = each.value.role
  member = google_service_account.stage[each.value.service_account].member
}

resource "google_organization_iam_member" "custom_viewer" {
  for_each = local.org_custom_viewer_roles

  org_id = var.org_id
  role   = google_organization_iam_custom_role.stage[each.key].name
  member = google_service_account.stage["iac-org-ro"].member
}
