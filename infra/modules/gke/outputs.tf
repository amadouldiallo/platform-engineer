# =============================================================================
# GKE Module Outputs
# =============================================================================

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.cluster.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.cluster.id
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster API server"
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The CA certificate of the cluster"
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location (region/zone) of the cluster"
  value       = google_container_cluster.cluster.location
}

output "cluster_self_link" {
  description = "The self-link of the cluster"
  value       = google_container_cluster.cluster.self_link
}

output "cluster_master_version" {
  description = "The Kubernetes master version"
  value       = google_container_cluster.cluster.master_version
}

# =============================================================================
# Workload Identity Outputs
# =============================================================================

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}

# Note: Service Account outputs disabled in lab projects
# output "workload_identity_sa_email" {
#   description = "Email of the Workload Identity service account"
#   value       = google_service_account.workload_identity_sa.email
# }
# 
# output "workload_identity_sa_name" {
#   description = "Name of the Workload Identity service account"
#   value       = google_service_account.workload_identity_sa.name
# }

# =============================================================================
# Node Pool Outputs
# =============================================================================

output "node_pool_name" {
  description = "The name of the default node pool"
  value       = "default-pool"  # Integrated node pool
}

# =============================================================================
# Connection Information
# =============================================================================

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.cluster.name} --region ${google_container_cluster.cluster.location} --project ${var.project_id}"
}
