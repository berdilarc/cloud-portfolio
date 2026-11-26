resource "google_compute_router" "default" {
  for_each = google_compute_network.vpc

  name    = "${each.key}-router"
  project = each.value.project
  region  = var.region
  network = each.value.id
}

resource "google_compute_router_nat" "default" {
  for_each = google_compute_router.default

  name                               = "${each.key}-nat"
  project                            = each.value.project
  region                             = each.value.region
  router                             = each.value.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
