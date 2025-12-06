# =============================================================================
# Project Configuration
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for zonal cluster (reduces costs/quotas). Set to null for regional cluster."
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "platform-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for the main subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.20.0.0/20"
}

# =============================================================================
# GKE Configuration
# =============================================================================

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "platform-cluster"
}

variable "gke_version" {
  description = "Kubernetes version for GKE"
  type        = string
  default     = "1.28"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode"
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Number of nodes in the cluster (Standard mode only, no autoscaling)"
  type        = number
  default     = 4  # 4 nodes for FluxCD + infra stack on e2-medium
}

variable "machine_type" {
  description = "Machine type for GKE nodes (Standard mode only)"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB for GKE nodes"
  type        = number
  default     = 20
}

# =============================================================================
# Labels and Tags
# =============================================================================

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "platform-engineer-poc"
  }
}

