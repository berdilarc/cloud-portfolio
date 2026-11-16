variable "project_id" {
  description = "ID of the seed project that holds the Terraform state bucket and the CI identities."
  type        = string
}

variable "region" {
  description = "Default region, also used as the location of the state bucket."
  type        = string
}
