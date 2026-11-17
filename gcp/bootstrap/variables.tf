variable "project_id" {
  description = "ID of the seed project that holds the Terraform state bucket and the CI identities."
  type        = string
}

variable "region" {
  description = "Default region, also used as the location of the state bucket."
  type        = string
}

variable "services" {
  description = "APIs to enable in the seed project. Removing an entry stops Terraform from managing the API but leaves it enabled."
  type        = set(string)
}

variable "github_repository" {
  description = "GitHub repository that runs the CI workflows, as owner/name."
  type        = string
}

variable "github_repository_id" {
  description = "Numeric ID of the GitHub repository. Only tokens issued to this repository are accepted."
  type        = string
}

variable "github_repository_owner_id" {
  description = "Numeric ID of the GitHub user or organization that owns the repository."
  type        = string
}

variable "github_apply_environment" {
  description = "GitHub environment whose jobs may impersonate the apply service account."
  type        = string
}
