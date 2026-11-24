variable "prefix" {
  type        = string
  description = "Short string that starts every globally unique name, such as project IDs and bucket names."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.prefix))
    error_message = "The prefix must be 2 to 8 lowercase letters or digits and start with a letter."
  }
}

variable "org_id" {
  type        = string
  description = "Numeric ID of the organization."
}

variable "billing_account" {
  type        = string
  description = "ID of the billing account linked to every project, as XXXXXX-XXXXXX-XXXXXX."
}

variable "region" {
  type        = string
  description = "Region for regional resources, such as the IaC buckets."
}

variable "resource_locations" {
  type        = list(string)
  description = "Locations where new resources may be created, such as in:us-locations. Sets the gcp.resourceLocations org policy."
}

variable "iac_project_services" {
  type        = set(string)
  description = "APIs to enable in the IaC core project. Removing an entry stops Terraform from managing the API but leaves it enabled."
}

variable "audit_logs_project_services" {
  type        = set(string)
  description = "APIs to enable in the audit logs project. Removing an entry stops Terraform from managing the API but leaves it enabled."
}

variable "github_repository_id" {
  type        = string
  description = "Numeric ID of the GitHub repository. Only tokens issued to this repository are accepted."
}

variable "github_repository_owner_id" {
  type        = string
  description = "Numeric ID of the GitHub user or organization that owns the repository."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository that runs the CI workflows, as owner/name."
}

variable "local_plan_principals" {
  type        = set(string)
  description = "IAM principals, such as user:name@example.com, that may impersonate the read-only stage service accounts to run terraform plan locally, and issue short-lived tokens for the agent service account."
  default     = []

  validation {
    condition     = !anytrue([for principal in var.local_plan_principals : startswith(principal, "serviceAccount:${google_service_account.agent.account_id}@")])
    error_message = "The agent service account already gets its plan bindings, so it can't be a local plan principal."
  }
}
