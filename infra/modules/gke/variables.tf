# =============================================================================
# GKE Module Variables
# =============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone for zonal cluster (reduces costs/quotas)"
  type        = string
  default     = null  # If null, creates regional cluster
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the pods secondary IP range"
  type        = string
}

variable "svc_range_name" {
  description = "Name of the services secondary IP range"
  type        = string
}

variable "gke_version" {
  description = "Kubernetes version"
  type        = string
}

variable "enable_autopilot" {
  description = "Enable Autopilot mode"
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Number of nodes in the cluster (no autoscaling for lab cost control)"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

