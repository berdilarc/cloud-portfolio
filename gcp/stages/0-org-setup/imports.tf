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
