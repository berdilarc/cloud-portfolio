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
