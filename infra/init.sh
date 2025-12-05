#!/bin/bash
# =============================================================================
# 🚀 Script d'initialisation rapide - Platform Engineer POC
# =============================================================================
#
# Usage:
#   ./init.sh <PROJECT_ID>
#
# Exemple:
#   ./init.sh kkgcplabs01-009
#
# Ce script:
#   1. Vérifie l'authentification
#   2. Crée le bucket GCS pour le state Terraform
#   3. Met à jour terraform.tfvars avec le nouveau project_id
#   4. Met à jour backend.tf avec le nouveau bucket
#   5. Initialise Terraform
#
# =============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Vérifier l'argument
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erreur: PROJECT_ID requis${NC}"
    echo ""
    echo "Usage: ./init.sh <PROJECT_ID>"
    echo "Exemple: ./init.sh kkgcplabs01-009"
    echo ""
    echo "Pour trouver votre PROJECT_ID:"
    echo "  gcloud config get-value project"
    exit 1
fi

PROJECT_ID=$1
BUCKET_NAME="${PROJECT_ID}-tf-state"
REGION="us-central1"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Initialisation Platform Engineer POC${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📋 Project ID: ${GREEN}${PROJECT_ID}${NC}"
echo -e "🪣 Bucket:     ${GREEN}${BUCKET_NAME}${NC}"
echo -e "🌍 Region:     ${GREEN}${REGION}${NC}"
echo ""

# =============================================================================
# Étape 1: Configurer gcloud
# =============================================================================
echo -e "${YELLOW}[1/6] Configuration de gcloud...${NC}"
gcloud config set project ${PROJECT_ID} 2>/dev/null || true
echo -e "${GREEN}✓ Projet configuré${NC}"

# =============================================================================
# Étape 2: Vérifier l'authentification
# =============================================================================
echo -e "${YELLOW}[2/6] Vérification de l'authentification...${NC}"

CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
echo -e "   Compte actuel: ${BLUE}${CURRENT_ACCOUNT}${NC}"

# Vérifier si le compte a accès au projet
if ! gcloud projects describe ${PROJECT_ID} &>/dev/null; then
    echo -e "${RED}❌ Le compte ${CURRENT_ACCOUNT} n'a pas accès au projet ${PROJECT_ID}${NC}"
    echo ""
    echo -e "${YELLOW}Vous devez vous réauthentifier avec le nouveau compte :${NC}"
    echo "  gcloud auth revoke --all"
    echo "  gcloud auth login"
    echo "  gcloud auth application-default login"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ Authentification OK${NC}"

# =============================================================================
# Étape 3: Créer le bucket GCS
# =============================================================================
echo -e "${YELLOW}[3/6] Création du bucket GCS...${NC}"

if gcloud storage buckets describe gs://${BUCKET_NAME} &>/dev/null; then
    echo -e "${GREEN}✓ Bucket existe déjà${NC}"
else
    # Afficher l'erreur si échec
    if ! gcloud storage buckets create gs://${BUCKET_NAME} \
        --project=${PROJECT_ID} \
        --location=${REGION} \
        --uniform-bucket-level-access; then
        echo -e "${RED}❌ Erreur création bucket.${NC}"
        echo ""
        echo -e "${YELLOW}Solutions possibles :${NC}"
        echo "  1. Réauthentifiez-vous: gcloud auth login"
        echo "  2. Vérifiez le projet: gcloud config set project ${PROJECT_ID}"
        echo "  3. Vérifiez vos permissions dans la console GCP"
        exit 1
    fi
    echo -e "${GREEN}✓ Bucket créé${NC}"
fi

# =============================================================================
# Étape 4: Mettre à jour backend.tf
# =============================================================================
echo -e "${YELLOW}[4/6] Mise à jour de backend.tf...${NC}"

cat > backend.tf << EOF
# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Généré automatiquement par init.sh le $(date '+%Y-%m-%d %H:%M:%S')
# Project: ${PROJECT_ID}
# =============================================================================

terraform {
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state"
  }
}
EOF
echo -e "${GREEN}✓ backend.tf mis à jour${NC}"

# =============================================================================
# Étape 5: Créer/Mettre à jour terraform.tfvars
# =============================================================================
echo -e "${YELLOW}[5/6] Mise à jour de terraform.tfvars...${NC}"

if [ -f terraform.tfvars.example ]; then
    sed "s/PROJECT_ID/${PROJECT_ID}/g" terraform.tfvars.example > terraform.tfvars
    echo -e "${GREEN}✓ terraform.tfvars créé depuis template${NC}"
else
    cat > terraform.tfvars << EOF
# Généré automatiquement par init.sh
project_id   = "${PROJECT_ID}"
region       = "us-central1"
zone         = "us-central1-a"
environment  = "dev"
cluster_name = "platform-cluster"
node_count   = 1
machine_type = "e2-medium"
disk_size_gb = 20

labels = {
  managed_by = "terraform"
  project    = "platform-engineer-poc"
}
EOF
    echo -e "${GREEN}✓ terraform.tfvars créé${NC}"
fi

# =============================================================================
# Étape 6: Initialiser Terraform
# =============================================================================
echo -e "${YELLOW}[6/6] Initialisation de Terraform...${NC}"

# Supprimer l'ancien state local si existe
rm -rf .terraform 2>/dev/null || true

terraform init -reconfigure
echo -e "${GREEN}✓ Terraform initialisé${NC}"

# =============================================================================
# Résumé
# =============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Initialisation terminée !${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Prochaines étapes:"
echo -e "  ${YELLOW}1.${NC} Vérifier le plan:     ${GREEN}terraform plan${NC}"
echo -e "  ${YELLOW}2.${NC} Déployer:             ${GREEN}terraform apply${NC}"
echo -e "  ${YELLOW}3.${NC} Se connecter au GKE:  ${GREEN}gcloud container clusters get-credentials platform-cluster --zone us-central1-a --project ${PROJECT_ID}${NC}"
echo ""
