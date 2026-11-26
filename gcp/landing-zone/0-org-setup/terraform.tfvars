region = "us-east1"

groups = {
  auditors            = "gcp-auditors"
  iac_operators       = "gcp-iac-operators"
  organization_admins = "gcp-organization-admins"
}

resource_locations = [
  "in:us-locations",
]

iac_project_services = [
  "cloudbilling.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "iam.googleapis.com",
  "iamcredentials.googleapis.com",
  "orgpolicy.googleapis.com",
  "storage.googleapis.com",
  "sts.googleapis.com",
]

audit_logs_project_services = [
  "bigquery.googleapis.com",
  "logging.googleapis.com",
]
