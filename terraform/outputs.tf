output "service_url" {
  value       = google_cloud_run_service.app.status[0].url
  description = "Deployed Cloud Run service URL"
}

output "artifact_registry_repo" {
  value       = google_artifact_registry_repository.repo.id
  description = "Artifact Registry repository ID"
}


