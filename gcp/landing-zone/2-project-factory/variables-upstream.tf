variable "folder_ids" {
  type        = map(string)
  description = "Folder resource names, as folders/<number>, keyed by path, such as teams. Set by the 0-org-setup tfvars file."
}
