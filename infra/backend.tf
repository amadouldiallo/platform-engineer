# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Généré automatiquement par init.sh le 2025-12-06 02:08:48
# Project: kkgcplabs01-032
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "kkgcplabs01-032-tf-state"
    prefix = "terraform/state"
  }
}
