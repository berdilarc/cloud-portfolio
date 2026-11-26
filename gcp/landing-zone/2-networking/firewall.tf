locals {
  ingress_allow_rules = {
    allow-healthchecks = {
      description    = "Allow SSH, HTTP, and HTTPS health checks."
      enable_logging = false
      priority       = 1001
      protocol       = "tcp"
      ports          = ["22", "80", "443"]
      # https://docs.cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
      source_ranges = [
        "35.191.0.0/16",
        "136.124.104.0/22",
        "136.124.108.0/22",
        "209.85.152.0/22",
        "209.85.204.0/22",
      ]
    }
    allow-ssh-from-iap = {
      description    = "Allow SSH from IAP TCP forwarding."
      enable_logging = true
      priority       = 1002
      protocol       = "tcp"
      ports          = ["22"]
      # https://docs.cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule
      source_ranges = ["35.235.240.0/20"]
    }
    allow-icmp = {
      description    = "Allow ICMP from private ranges."
      enable_logging = false
      priority       = 1003
      protocol       = "icmp"
      ports          = null
      source_ranges  = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }
  }
}

resource "google_compute_network_firewall_policy" "vpc" {
  for_each = google_compute_network.vpc

  name        = each.value.name
  description = "Allow rules for the ${each.value.name} VPC."
  project     = each.value.project
}

resource "google_compute_network_firewall_policy_rule" "ingress_allow" {
  for_each = {
    for pair in setproduct(keys(google_compute_network_firewall_policy.vpc), keys(local.ingress_allow_rules)) :
    "${pair[0]} ${pair[1]}" => merge(local.ingress_allow_rules[pair[1]], {
      name   = pair[1]
      policy = pair[0]
    })
  }

  rule_name       = each.value.name
  description     = each.value.description
  project         = google_compute_network_firewall_policy.vpc[each.value.policy].project
  firewall_policy = google_compute_network_firewall_policy.vpc[each.value.policy].name
  direction       = "INGRESS"
  priority        = each.value.priority
  action          = "allow"
  enable_logging  = each.value.enable_logging

  match {
    src_ip_ranges = each.value.source_ranges

    layer4_configs {
      ip_protocol = each.value.protocol
      ports       = each.value.ports
    }
  }
}

resource "google_compute_network_firewall_policy_association" "vpc" {
  for_each = google_compute_network_firewall_policy.vpc

  name              = each.value.name
  project           = each.value.project
  firewall_policy   = each.value.name
  attachment_target = google_compute_network.vpc[each.key].id
}

resource "google_compute_firewall" "ingress_deny" {
  for_each = google_compute_network.vpc

  name          = "ingress-default-deny"
  description   = "Deny and log any unmatched ingress traffic."
  project       = each.value.project
  network       = each.value.id
  direction     = "INGRESS"
  priority      = 65535
  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}
