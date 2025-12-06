# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Généré automatiquement par init.sh le 2025-12-06 17:50:01
# Project: kkgcplabs01-042
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "kkgcplabs01-042-tf-state"
    prefix = "terraform/state"
  }
}
