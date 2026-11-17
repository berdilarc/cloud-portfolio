output "tf_state_bucket" {
  description = "Name of the bucket that stores Terraform state for every stack."
  value       = google_storage_bucket.tf_state.name
}

output "iac_service_accounts" {
  description = "Email of each CI service account, keyed by account ID."
  value       = { for id, sa in google_service_account.iac : id => sa.email }
}
