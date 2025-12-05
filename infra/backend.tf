# =============================================================================
# Terraform Backend Configuration
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "kkgcplabs01-009-tf-state"
    prefix = "terraform/state"
  }
}
