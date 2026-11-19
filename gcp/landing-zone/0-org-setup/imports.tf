import {
  to = google_project.iac
  id = local.iac_project_id
}

import {
  to = google_project.billing_export
  id = local.billing_export_project_id
}

import {
  for_each = var.iac_project_services

  to = google_project_service.iac[each.key]
  id = "${local.iac_project_id}/${each.key}"
}

import {
  to = google_iam_workload_identity_pool.github
  id = "projects/${local.iac_project_id}/locations/global/workloadIdentityPools/github"
}

import {
  to = google_iam_workload_identity_pool_provider.github_actions
  id = "projects/${local.iac_project_id}/locations/global/workloadIdentityPools/github/providers/github-actions"
}
