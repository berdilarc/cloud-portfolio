locals {
  billing_account_roles = {
    "iac-networking-rw" = "roles/billing.user"
    "iac-org-ro"        = "roles/billing.viewer"
    "iac-org-rw"        = "roles/billing.admin"
    "iac-pf-rw"         = "roles/billing.user"
  }
}

resource "google_billing_account_iam_member" "stage" {
  for_each = local.billing_account_roles

  billing_account_id = var.billing_account
  role               = each.value
  member             = google_service_account.stage[each.key].member
}
