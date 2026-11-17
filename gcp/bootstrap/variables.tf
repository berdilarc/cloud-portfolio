variable "project_id" {
  type        = string
  description = "ID of the seed project that holds the Terraform state bucket and the CI identities."
}

variable "region" {
  type        = string
  description = "Default region, also used as the location of the state bucket."
}

variable "services" {
  type        = set(string)
  description = "APIs to enable in the seed project. Removing an entry stops Terraform from managing the API but leaves it enabled."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository that runs the CI workflows, as owner/name."
}

variable "github_repository_id" {
  type        = string
  description = "Numeric ID of the GitHub repository. Only tokens issued to this repository are accepted."
}

variable "github_repository_owner_id" {
  type        = string
  description = "Numeric ID of the GitHub user or organization that owns the repository."
}

variable "github_apply_environment" {
  type        = string
  description = "GitHub environment whose jobs may impersonate the apply service account."
}
