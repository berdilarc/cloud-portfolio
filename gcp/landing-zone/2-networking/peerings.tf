locals {
  peerings = {
    hub-to-dev = {
      network      = "hub"
      peer_network = "dev"
    }
    hub-to-prod = {
      network      = "hub"
      peer_network = "prod"
    }
    dev-to-hub = {
      network      = "dev"
      peer_network = "hub"
    }
    prod-to-hub = {
      network      = "prod"
      peer_network = "hub"
    }
  }
}

resource "google_compute_network_peering" "hub_spoke" {
  for_each = local.peerings

  name                 = each.key
  network              = google_compute_network.vpc[each.value.network].id
  peer_network         = google_compute_network.vpc[each.value.peer_network].id
  export_custom_routes = true
  import_custom_routes = true
}
