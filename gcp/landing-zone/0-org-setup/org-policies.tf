locals {
  enforced_org_policies = toset([
    "compute.managed.requireOsLogin",
    "compute.skipDefaultNetworkCreation",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "iam.disableServiceAccountKeyUpload",
    "iam.managed.disableServiceAccountKeyCreation",
    "storage.uniformBucketLevelAccess",
  ])
}

data "google_organization" "this" {
  organization = "organizations/${var.org_id}"
}

resource "google_org_policy_policy" "enforced" {
  for_each = local.enforced_org_policies

  name   = "organizations/${var.org_id}/policies/${each.key}"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "protocol_forwarding" {
  name   = "organizations/${var.org_id}/policies/compute.managed.restrictProtocolForwardingCreationForTypes"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
      parameters = jsonencode({
        allowedSchemes = ["INTERNAL"]
      })
    }
  }
}

resource "google_org_policy_policy" "contact_domains" {
  name   = "organizations/${var.org_id}/policies/essentialcontacts.managed.allowedContactDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
      parameters = jsonencode({
        allowedDomains = ["@${data.google_organization.this.domain}"]
      })
    }
  }
}

resource "google_org_policy_policy" "member_domains" {
  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [data.google_organization.this.directory_customer_id]
      }
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "organizations/${var.org_id}/policies/gcp.resourceLocations"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = var.resource_locations
      }
    }
  }
}

resource "google_org_policy_policy" "credential_lifetime" {
  name   = "organizations/${var.org_id}/policies/iam.allowServiceAccountCredentialLifetimeExtension"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [google_service_account.agent.email]
      }
    }
  }
}
