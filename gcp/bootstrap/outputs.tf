output "tf_state_bucket" {
  description = "Name of the bucket that stores Terraform state for every stack."
  value       = google_storage_bucket.tf_state.name
}
