locals {
  ingress_allow_rules = {
    allow-healthchecks = {
      description        = "Allow SSH, HTTP, and HTTPS health checks to VMs tagged firewall/http-server."
      enable_logging     = false
      priority           = 1001
      protocol           = "tcp"
      ports              = ["22", "80", "443"]
      target_secure_tags = ["firewall/http-server"]
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
      description        = "Allow SSH from IAP TCP forwarding."
      enable_logging     = true
      priority           = 1002
      protocol           = "tcp"
      ports              = ["22"]
      target_secure_tags = []
      # https://docs.cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule
      source_ranges = ["35.235.240.0/20"]
    }
    allow-icmp = {
      description        = "Allow ICMP from private ranges."
      enable_logging     = false
      priority           = 1003
      protocol           = "icmp"
      ports              = null
      target_secure_tags = []
      source_ranges      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }
  }
}

resource "google_compute_firewall_policy" "networking" {
  short_name  = "network-policy"
  description = "Allow rules for every VPC in the Networking folder."
  parent      = var.folder_ids["networking"]
}

resource "google_compute_firewall_policy_rule" "ingress_allow" {
  for_each = local.ingress_allow_rules

  description     = each.value.description
  firewall_policy = google_compute_firewall_policy.networking.name
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

  dynamic "target_secure_tags" {
    for_each = toset(each.value.target_secure_tags)

    content {
      name = var.tag_values[target_secure_tags.key]
    }
  }
}

resource "google_compute_firewall_policy_association" "networking" {
  name              = "networking"
  firewall_policy   = google_compute_firewall_policy.networking.id
  attachment_target = var.folder_ids["networking"]
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
