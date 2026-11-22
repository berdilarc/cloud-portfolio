output "storage_buckets" {
  description = "Name of each automation bucket, keyed by purpose."
  value       = local.storage_buckets
}

output "service_accounts" {
  description = "Email of each stage, CI/CD, and agent service account, keyed by account ID."
  value = merge(
    { for id, sa in google_service_account.stage : id => sa.email },
    { for id, sa in google_service_account.cicd : id => sa.email },
    { (google_service_account.agent.account_id) = google_service_account.agent.email },
  )
}

output "workload_identity_provider" {
  description = "Full resource name of the GitHub Actions provider, the workload_identity_provider input of google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "provider_files" {
  description = "Cloud Storage URI of each generated providers file, keyed by stage, with -ro for the read-only variant."
  value       = { for id, file in google_storage_bucket_object.providers : id => "gs://${file.bucket}/${file.name}" }
}
