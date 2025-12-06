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
    "iam.googleapis.com",  # Needed for Crossplane Workload Identity
    "storage-api.googleapis.com",  # Needed for GCS buckets
    "sqladmin.googleapis.com",  # Needed for CloudSQL (Brique 3)
    # Note: APIs below may require elevated permissions in lab projects
    # "cloudresourcemanager.googleapis.com",
    # "servicenetworking.googleapis.com",  # Needed for CloudSQL (Brique 3)
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

# =============================================================================
# Crossplane Service Account (Workload Identity)
# =============================================================================
# Service Account GCP pour Crossplane avec Workload Identity
# Permet à Crossplane de créer des ressources GCP sans clés
#
# ⚠️ NOTE LAB: Désactivé car le projet lab n'a pas les permissions
#    iam.serviceAccounts.create. Crossplane utilisera le Service Account
#    par défaut du compute ou une clé manuelle.
# =============================================================================

# Service Account GCP pour Crossplane
# DÉSACTIVÉ dans les projets lab (permissions insuffisantes)
# resource "google_service_account" "crossplane" {
#   account_id   = "crossplane-sa"
#   project      = var.project_id
#   display_name = "Crossplane Service Account"
#   description  = "Service Account for Crossplane to provision GCP resources via Workload Identity"
# }

# Permissions IAM pour Crossplane
# DÉSACTIVÉ - nécessite le Service Account ci-dessus
# resource "google_project_iam_member" "crossplane_storage_admin" {
#   project = var.project_id
#   role    = "roles/storage.admin"
#   member  = "serviceAccount:${google_service_account.crossplane.email}"
# }

# resource "google_project_iam_member" "crossplane_sql_admin" {
#   project = var.project_id
#   role    = "roles/cloudsql.admin"
#   member  = "serviceAccount:${google_service_account.crossplane.email}"
# }

# resource "google_project_iam_member" "crossplane_pubsub_admin" {
#   project = var.project_id
#   role    = "roles/pubsub.admin"
#   member  = "serviceAccount:${google_service_account.crossplane.email}"
# }

# Workload Identity Binding
# DÉSACTIVÉ - nécessite le Service Account ci-dessus
# resource "google_service_account_iam_member" "crossplane_workload_identity" {
#   service_account_id = google_service_account.crossplane.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:${var.project_id}.svc.id.goog[crossplane-system/crossplane]"
# }

