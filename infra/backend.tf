# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Généré automatiquement par init.sh le 2025-12-05 21:05:09
# Project: kkgcplabs01-007
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "kkgcplabs01-007-tf-state"
    prefix = "terraform/state"
  }
}
