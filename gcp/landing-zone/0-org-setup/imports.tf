import {
  for_each = toset([
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "iam.disableServiceAccountKeyUpload",
    "iam.managed.disableServiceAccountKeyCreation",
    "storage.uniformBucketLevelAccess",
  ])

  to = google_org_policy_policy.enforced[each.key]
  id = "organizations/${var.org_id}/policies/${each.key}"
}

import {
  to = google_org_policy_policy.protocol_forwarding
  id = "organizations/${var.org_id}/policies/compute.managed.restrictProtocolForwardingCreationForTypes"
}

import {
  to = google_org_policy_policy.contact_domains
  id = "organizations/${var.org_id}/policies/essentialcontacts.managed.allowedContactDomains"
}

import {
  to = google_org_policy_policy.member_domains
  id = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
}
