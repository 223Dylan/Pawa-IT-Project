locals {
  effective_image = var.container_image != "" ? var.container_image : "us-docker.pkg.dev/cloudrun/container/hello"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
  ])
  project = var.project_id
  service = each.key
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.repo_id
  description   = "Insight-Agent images"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "run_sa" {
  account_id   = "insight-agent-runner"
  display_name = "Insight-Agent Cloud Run SA"
}

# Allow the Cloud Run runtime SA to read from Artifact Registry repo
resource "google_artifact_registry_repository_iam_member" "repo_reader" {
  location   = google_artifact_registry_repository.repo.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_cloud_run_service" "app" {
  name     = var.service_name
  location = var.region

  autogenerate_revision_name = true

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = var.ingress
    }
  }

  template {
    spec {
      service_account_name = google_service_account.run_sa.email

      containers {
        image = local.effective_image
        ports {
          name           = "http1"
          container_port = 8080
        }
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        env {
          name  = "PORT"
          value = "8080"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.repo,
    google_service_account.run_sa,
  ]
}

# Grant invoker to specific principals only; do NOT bind allUsers/allAuthenticatedUsers
resource "google_cloud_run_service_iam_member" "invokers" {
  for_each = toset(var.allowed_invokers)

  location = var.region
  project  = var.project_id
  service  = google_cloud_run_service.app.name
  role     = "roles/run.invoker"
  member   = each.value
}
