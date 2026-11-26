locals {
  private_zones = {
    hub = {
      name            = "pvt-test"
      dns_name        = "test."
      client_networks = ["hub"]
    }
    dev = {
      name            = "pvt-dev-test"
      dns_name        = "dev.test."
      client_networks = ["dev", "hub"]
    }
    prod = {
      name            = "pvt-prod-test"
      dns_name        = "prod.test."
      client_networks = ["prod", "hub"]
    }
  }
}

resource "google_dns_managed_zone" "private" {
  for_each = local.private_zones

  name       = each.value.name
  project    = google_project.host[each.key].project_id
  dns_name   = each.value.dns_name
  visibility = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = toset(each.value.client_networks)

      content {
        network_url = google_compute_network.vpc[networks.key].id
      }
    }
  }
}

resource "google_dns_record_set" "localhost" {
  for_each = google_dns_managed_zone.private

  name         = "localhost.${each.value.dns_name}"
  project      = each.value.project
  managed_zone = each.value.name
  type         = "A"
  ttl          = 300
  rrdatas      = ["127.0.0.1"]
}

resource "google_dns_managed_zone" "peering" {
  name       = "peer-root"
  project    = google_project.host["hub"].project_id
  dns_name   = "."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc["dev"].id
    }
    networks {
      network_url = google_compute_network.vpc["prod"].id
    }
  }

  peering_config {
    target_network {
      network_url = google_compute_network.vpc["hub"].id
    }
  }
}
