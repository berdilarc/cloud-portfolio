variable "folder_ids" {
  type        = map(string)
  description = "Folder resource names, as folders/<number>, keyed by path, such as networking/dev. Set by the 0-org-setup tfvars file."
}

variable "tag_values" {
  type        = map(string)
  description = "Tag value resource names, as tagValues/<number>, keyed by key/value, such as firewall/http-server. Set by the 0-org-setup tfvars file."
}
