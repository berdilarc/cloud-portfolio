resource "google_organization_iam_custom_role" "storage_viewer" {
  role_id     = "storageViewer"
  org_id      = var.org_id
  title       = "Storage Viewer with IAM"
  description = "Read buckets, managed folders and objects, plus bucket and managed folder IAM policies."
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
