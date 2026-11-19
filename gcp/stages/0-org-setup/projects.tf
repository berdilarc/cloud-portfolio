resource "google_project" "iac" {
  name                = "IaC Core"
  project_id          = local.iac_project_id
  org_id              = var.org_id
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "iac" {
  for_each = var.iac_project_services

  project            = google_project.iac.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project" "billing_export" {
  name                = "Billing Export"
  project_id          = local.billing_export_project_id
  org_id              = var.org_id
  billing_account     = var.billing_account
  auto_create_network = false
}
