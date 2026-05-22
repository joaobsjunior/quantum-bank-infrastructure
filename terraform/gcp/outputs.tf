output "service_urls" {
  description = "Cloud Run service URIs by Quantum Bank service key."
  value = {
    for key, service in google_cloud_run_v2_service.service : key => service.uri
  }
}

output "runtime_service_account" {
  description = "Runtime service account email."
  value       = google_service_account.runtime.email
}
