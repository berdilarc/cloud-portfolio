locals {
  subnets = {
    hub = {
      ip_cidr_range       = "10.71.0.0/24"
      secondary_ip_ranges = {}
    }
    dev = {
      ip_cidr_range = "10.73.0.0/24"
      secondary_ip_ranges = {
        pods     = "10.73.64.0/18"
        services = "10.73.16.0/20"
      }
    }
    prod = {
      ip_cidr_range = "10.72.0.0/24"
      secondary_ip_ranges = {
        pods     = "10.72.64.0/18"
        services = "10.72.16.0/20"
      }
    }
  }
}

resource "google_compute_network" "vpc" {
  for_each = google_project.host

  name                                      = "${each.key}-0"
  project                                   = each.value.project_id
  auto_create_subnetworks                   = false
  routing_mode                              = "GLOBAL"
  network_firewall_policy_enforcement_order = "BEFORE_CLASSIC_FIREWALL"

  depends_on = [google_project_service.host]
}

resource "google_compute_subnetwork" "default" {
  for_each = local.subnets

  name                     = "${each.key}-default"
  project                  = google_compute_network.vpc[each.key].project
  region                   = var.region
  network                  = google_compute_network.vpc[each.key].id
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges

    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}
