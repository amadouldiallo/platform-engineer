#!/bin/bash
# =============================================================================
# Script: Mise à jour de la configuration Crossplane après terraform apply
# =============================================================================
# Ce script met à jour les placeholders dans les fichiers Crossplane
# avec les valeurs réelles du projet GCP
# =============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier que terraform a été appliqué
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo -e "${RED}❌ Erreur: terraform.tfstate non trouvé${NC}"
    echo "   Exécutez d'abord: terraform apply"
    exit 1
fi

# Récupérer les valeurs depuis Terraform
echo -e "${YELLOW}📋 Récupération des valeurs depuis Terraform...${NC}"

PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || terraform output project_id 2>/dev/null | tr -d '"')
CROSSPLANE_SA_EMAIL=$(terraform output -raw crossplane_service_account_email 2>/dev/null || terraform output crossplane_service_account_email 2>/dev/null | tr -d '"')

if [ -z "$PROJECT_ID" ] || [ -z "$CROSSPLANE_SA_EMAIL" ]; then
    echo -e "${RED}❌ Erreur: Impossible de récupérer les valeurs depuis Terraform${NC}"
    echo "   Vérifiez que terraform apply a été exécuté avec succès"
    exit 1
fi

echo -e "${GREEN}✅ Project ID: ${PROJECT_ID}${NC}"
echo -e "${GREEN}✅ Crossplane SA: ${CROSSPLANE_SA_EMAIL}${NC}"

# Chemin vers les fichiers Crossplane
CROSSPLANE_DIR="../gitops/infrastructure/controllers/crossplane"

if [ ! -d "$CROSSPLANE_DIR" ]; then
    echo -e "${RED}❌ Erreur: Dossier Crossplane non trouvé: ${CROSSPLANE_DIR}${NC}"
    exit 1
fi

# Mettre à jour providerconfig-gcp.yaml
echo -e "${YELLOW}📝 Mise à jour de providerconfig-gcp.yaml...${NC}"
sed -i "s/PROJECT_ID_PLACEHOLDER/${PROJECT_ID}/g" "${CROSSPLANE_DIR}/providerconfig-gcp.yaml"

# Mettre à jour serviceaccount.yaml
echo -e "${YELLOW}📝 Mise à jour de serviceaccount.yaml...${NC}"
sed -i "s|CROSSPLANE_SA_EMAIL_PLACEHOLDER|${CROSSPLANE_SA_EMAIL}|g" "${CROSSPLANE_DIR}/serviceaccount.yaml"

echo -e "${GREEN}✅ Configuration Crossplane mise à jour !${NC}"
echo ""
echo -e "${YELLOW}📋 Prochaines étapes:${NC}"
echo "   1. Vérifier les fichiers modifiés:"
echo "      - ${CROSSPLANE_DIR}/providerconfig-gcp.yaml"
echo "      - ${CROSSPLANE_DIR}/serviceaccount.yaml"
echo ""
echo "   2. Commit et push les changements:"
echo "      git add ${CROSSPLANE_DIR}/"
echo "      git commit -m 'chore(crossplane): update config with terraform outputs'"
echo "      git push"
echo ""
echo "   3. FluxCD appliquera automatiquement la configuration"

