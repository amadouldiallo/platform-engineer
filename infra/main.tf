# =============================================================================
# Platform Engineer POC - Main Infrastructure
# =============================================================================
#
# This Terraform configuration creates a minimal cloud-native platform on GCP:
# - VPC Network with subnets optimized for GKE
# - GKE Cluster with Workload Identity enabled
#
# =============================================================================

locals {
  common_labels = merge(var.labels, {
    environment = var.environment
  })
}

# =============================================================================
# Enable Required GCP APIs
# =============================================================================

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    # Note: APIs below may require elevated permissions in lab projects
    # "cloudresourcemanager.googleapis.com",
    # "iam.googleapis.com",
    # "servicenetworking.googleapis.com",  # Needed for CloudSQL (Brique 3)
    # "sqladmin.googleapis.com",           # Needed for CloudSQL (Brique 3)
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# =============================================================================
# Network Module
# =============================================================================

module "network" {
  source = "./modules/network"

  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
  labels        = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# =============================================================================
# GKE Cluster Module
# =============================================================================

module "gke" {
  source = "./modules/gke"

  project_id       = var.project_id
  region           = var.region
  zone             = var.zone  # Zonal cluster to save quota
  cluster_name     = var.cluster_name
  network_name     = module.network.network_name
  subnet_name      = module.network.subnet_name
  pods_range_name  = module.network.pods_range_name
  svc_range_name   = module.network.services_range_name
  gke_version      = var.gke_version
  enable_autopilot = var.enable_autopilot
  node_count       = var.node_count
  machine_type     = var.machine_type
  disk_size_gb     = var.disk_size_gb
  labels           = local.common_labels

  depends_on = [module.network]
}

