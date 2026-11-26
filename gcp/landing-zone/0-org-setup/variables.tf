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

variable "domain" {
  type        = string
  description = "Domain of the organization and its Cloud Identity groups."
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

variable "groups" {
  type = object({
    auditors            = string
    iac_operators       = string
    organization_admins = string
  })
  description = "Names of the Cloud Identity groups that get roles from this stage, without the domain: organization_admins administer the organization and the billing account, iac_operators run local plans and issue agent tokens, and auditors read IAM policies, billing data, and the audit logs."
}
