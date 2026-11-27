locals {
  firewall_tag_roles = {
    "iac-networking-rw" = "roles/resourcemanager.tagUser"
    "iac-networking-ro" = "roles/resourcemanager.tagViewer"
  }
}

resource "google_tags_tag_key" "firewall" {
  description = "Secure Tags that select VMs as targets or sources of Cloud NGFW policy rules."
  parent      = local.org_name
  purpose     = "GCE_FIREWALL"
  short_name  = "firewall"
  purpose_data = {
    organization = "auto"
  }
}

resource "google_tags_tag_value" "firewall_http_server" {
  description = "VMs that serve HTTP and HTTPS behind a load balancer."
  parent      = google_tags_tag_key.firewall.id
  short_name  = "http-server"
}

resource "google_tags_tag_value_iam_member" "firewall_http_server" {
  for_each = local.firewall_tag_roles

  tag_value = google_tags_tag_value.firewall_http_server.id
  role      = each.value
  member    = google_service_account.stage[each.key].member
}
