variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "repo_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "insight-agent"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "insight-agent"
}

variable "container_image" {
  description = "Container image URI to deploy to Cloud Run"
  type        = string
  default     = ""
}

variable "allowed_invokers" {
  description = "List of principals allowed to invoke the Cloud Run service (e.g., user:you@example.com, serviceAccount:sa@project.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "ingress" {
  description = "Cloud Run ingress policy (all or internal-and-cloud-load-balancing)"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "internal-and-cloud-load-balancing"], var.ingress)
    error_message = "ingress must be one of: all, internal-and-cloud-load-balancing"
  }
}
