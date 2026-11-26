variable "prefix" {
  type        = string
  description = "Short string that starts every globally unique name, such as project IDs."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.prefix))
    error_message = "The prefix must be 2 to 8 lowercase letters or digits and start with a letter."
  }
}

variable "billing_account" {
  type        = string
  description = "ID of the billing account linked to every project, as XXXXXX-XXXXXX-XXXXXX."
}

variable "region" {
  type        = string
  description = "Region for regional resources, such as the subnets."
}

variable "host_project_services" {
  type        = set(string)
  description = "APIs to enable in every host project. Removing an entry stops Terraform from managing the API but leaves it enabled."
}
