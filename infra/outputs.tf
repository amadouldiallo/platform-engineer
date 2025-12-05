# =============================================================================
# Network Outputs
# =============================================================================

output "network_name" {
  description = "The name of the VPC network"
  value       = module.network.network_name
}

output "network_self_link" {
  description = "The self-link of the VPC network"
  value       = module.network.network_self_link
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = module.network.subnet_name
}

output "subnet_self_link" {
  description = "The self-link of the subnet"
  value       = module.network.subnet_self_link
}

# =============================================================================
# GKE Outputs
# =============================================================================

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = module.gke.cluster_location
}

# =============================================================================
# Connection Commands
# =============================================================================

output "gke_connect_command" {
  description = "Command to configure kubectl for the GKE cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = module.gke.workload_identity_pool
}

