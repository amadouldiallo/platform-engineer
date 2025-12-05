# =============================================================================
# GKE Module - Kubernetes Cluster with Workload Identity
# =============================================================================
#
# This module creates:
# - GKE Cluster (Standard mode) with integrated node pool
# - Workload Identity enabled for secure GCP service access
# - Security best practices (private nodes, shielded nodes)
#
# Note: Using integrated node pool to avoid org policy issues with default pool
#
# =============================================================================

# =============================================================================
# GKE Cluster (Standard Mode with Integrated Node Pool)
# =============================================================================

resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  project  = var.project_id
  # Use zone for zonal cluster (1 node) or region for regional (3 nodes)
  location = var.zone != null ? var.zone : var.region

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

  # Integrated node pool configuration (avoids org policy issues with default pool)
  # Do NOT use remove_default_node_pool as it creates a temp pool with default disk size
  initial_node_count = var.node_count

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
      node_pool = "default"
    })

    # Node tags for firewall rules
    tags = ["gke-node", "${var.cluster_name}-node"]

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Deletion protection (disable for POC, enable in production)
  deletion_protection = false
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
