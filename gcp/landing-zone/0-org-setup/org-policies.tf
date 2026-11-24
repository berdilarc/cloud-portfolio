locals {
  org_policy_prefix = "${local.org_name}/policies"

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
  organization = local.org_name
}

resource "google_org_policy_policy" "enforced" {
  for_each = local.enforced_org_policies

  name   = "${local.org_policy_prefix}/${each.key}"
  parent = local.org_name

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "protocol_forwarding" {
  name   = "${local.org_policy_prefix}/compute.managed.restrictProtocolForwardingCreationForTypes"
  parent = local.org_name

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
  name   = "${local.org_policy_prefix}/essentialcontacts.managed.allowedContactDomains"
  parent = local.org_name

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
  name   = "${local.org_policy_prefix}/iam.allowedPolicyMemberDomains"
  parent = local.org_name

  spec {
    rules {
      values {
        allowed_values = [data.google_organization.this.directory_customer_id]
      }
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${local.org_policy_prefix}/gcp.resourceLocations"
  parent = local.org_name

  spec {
    rules {
      values {
        allowed_values = var.resource_locations
      }
    }
  }
}

resource "google_org_policy_policy" "credential_lifetime" {
  name   = "${local.org_policy_prefix}/iam.allowServiceAccountCredentialLifetimeExtension"
  parent = local.org_name

  spec {
    rules {
      values {
        allowed_values = [google_service_account.agent.email]
      }
    }
  }
}
