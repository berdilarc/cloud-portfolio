region = "us-east1"

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
  "logging.googleapis.com",
]
