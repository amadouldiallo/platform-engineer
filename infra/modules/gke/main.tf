# =============================================================================
# GKE Module - Kubernetes Cluster with Workload Identity
# =============================================================================
#
# This module creates:
# - GKE Cluster (Standard mode) with separate node pool
# - Workload Identity enabled for secure GCP service access
# - Security best practices (private nodes, shielded nodes)
#
# Configuration for Lab environment:
# - Configurable nodes e2-medium (no autoscaling for cost control)
# - 20GB disk per node (lab quota limit)
# - Zonal cluster to reduce resource usage
#
# =============================================================================

# =============================================================================
# GKE Cluster (Standard Mode)
# =============================================================================

resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  project  = var.project_id
  # Use zone for zonal cluster or region for regional
  location = var.zone != null ? var.zone : var.region

  # Remove default node pool - we'll create our own
  # ⚠️ initial_node_count = 0 pour éviter la création d'un pool temporaire
  #    avec disk size par défaut (100GB) qui dépasse la limite org policy (50GB)
  remove_default_node_pool = true
  initial_node_count       = 0

  # Network configuration
  network    = var.network_name
  subnetwork = var.subnet_name

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.svc_range_name
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks (restrict API access)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks (restrict in production)"
    }
  }

  # Workload Identity (key feature for secure GCP access)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel for automatic upgrades
  release_channel {
    channel = "REGULAR"
  }

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Maintenance window (daily 2-6 AM to meet GKE requirements)
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=DAILY"
    }
  }

  # Security posture
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Resource labels
  resource_labels = var.labels

  # Deletion protection (disable for POC, enable in production)
  deletion_protection = false
}

# =============================================================================
# Node Pool (Separate resource for easy scaling via Terraform)
# =============================================================================

resource "google_container_node_pool" "primary" {
  name       = "primary-pool"
  project    = var.project_id
  location   = var.zone != null ? var.zone : var.region
  cluster    = google_container_cluster.cluster.name
  
  # Number of nodes - can be changed without recreating cluster
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    # OAuth scopes (minimal for Workload Identity)
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Service account (use default compute SA)
    service_account = "default"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance configuration
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Node labels
    labels = merge(var.labels, {
      node_pool = "primary"
    })

    # Node tags for firewall rules
    tags = ["gke-node", "${var.cluster_name}-node"]

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Management settings
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# =============================================================================
# Service Account for Workload Identity
# =============================================================================
# Note: Disabled in lab projects due to IAM permission restrictions
# Uncomment in production environments
#
# resource "google_service_account" "workload_identity_sa" {
#   account_id   = "${var.cluster_name}-wi-sa"
#   project      = var.project_id
#   display_name = "Workload Identity SA for ${var.cluster_name}"
#   description  = "Service account for Kubernetes workloads using Workload Identity"
# }
