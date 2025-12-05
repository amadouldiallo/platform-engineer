# =============================================================================
# Network Module - VPC and Subnets for GKE
# =============================================================================
#
# This module creates:
# - VPC Network with custom mode
# - Subnet with secondary ranges for GKE pods and services
# - Cloud NAT for outbound internet access
# - Firewall rules for internal communication
#
# =============================================================================

# =============================================================================
# VPC Network
# =============================================================================

resource "google_compute_network" "vpc" {
  name                            = var.network_name
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

# =============================================================================
# Subnet with Secondary Ranges for GKE
# =============================================================================

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.network_name}-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  # Secondary ranges for GKE
  secondary_ip_range {
    range_name    = "${var.network_name}-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.network_name}-services"
    ip_cidr_range = var.services_cidr
  }

  # VPC Flow Logs - reduced sampling for lab org policy compliance
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.1  # Must be < 30% per org policy
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# =============================================================================
# Cloud Router (required for Cloud NAT)
# =============================================================================

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# =============================================================================
# Cloud NAT (for outbound internet access from private nodes)
# =============================================================================

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Note: NAT logging disabled due to org policy constraint
  # log_config {
  #   enable = true
  #   filter = "ERRORS_ONLY"
  # }
}

# =============================================================================
# Firewall Rules
# =============================================================================

# Allow internal communication within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr,
  ]

  priority = 1000
}

# Allow health checks from GCP load balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.network_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }

  # GCP Health Check ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  target_tags = ["gke-node"]
  priority    = 1000
}

# Allow SSH access (for debugging - restrict in production)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP tunnel range for secure SSH
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["gke-node"]
  priority      = 1000
}
