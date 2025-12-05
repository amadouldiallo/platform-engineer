# 🏗️ Infrastructure GCP - Terraform

Ce module Terraform provisionne l'infrastructure GCP nécessaire pour la plateforme cloud-native.

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GCP Project: kkgcplabs01-009                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     Terraform State (GCS)                               │ │
│  │                gs://kkgcplabs01-009-tf-state                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      VPC Network: platform-vpc                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │              Subnet: platform-vpc-subnet (us-central1)            │  │ │
│  │  │  • Primary CIDR: 10.0.0.0/20                                     │  │ │
│  │  │  • Pods CIDR: 10.16.0.0/14 (secondary range)                     │  │ │
│  │  │  • Services CIDR: 10.20.0.0/20 (secondary range)                 │  │ │
│  │  │                                                                   │  │ │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │  │ │
│  │  │  │     GKE Cluster: platform-cluster (us-central1-a)           │  │  │ │
│  │  │  │  ┌──────────────────────────────────────────────────────┐  │  │  │ │
│  │  │  │  │              Node Pool: default-pool                  │  │  │  │ │
│  │  │  │  │  • Machine: e2-medium                                 │  │  │  │ │
│  │  │  │  │  • Disk: 20GB (org policy limit: 50GB)                │  │  │  │ │
│  │  │  │  │  • Nodes: 1 (zonal cluster)                           │  │  │  │ │
│  │  │  │  │  • Private nodes (no public IP)                       │  │  │  │ │
│  │  │  │  │  • Shielded nodes enabled                             │  │  │  │ │
│  │  │  │  └──────────────────────────────────────────────────────┘  │  │  │ │
│  │  │  │                                                             │  │  │ │
│  │  │  │  Features:                                                  │  │  │ │
│  │  │  │  ✓ Workload Identity                                        │  │  │ │
│  │  │  │  ✓ Network Policy (Calico)                                  │  │  │ │
│  │  │  │  ✓ Managed Prometheus                                       │  │  │ │
│  │  │  │  ✓ VPC-native networking                                    │  │  │ │
│  │  │  └────────────────────────────────────────────────────────────┘  │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  ┌─────────────────┐    ┌─────────────────┐                            │ │
│  │  │  Cloud Router   │────│    Cloud NAT    │──── Internet               │ │
│  │  │ platform-vpc-   │    │ platform-vpc-   │                            │ │
│  │  │    router       │    │      nat        │                            │ │
│  │  └─────────────────┘    └─────────────────┘                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Firewall Rules:                                                             │
│  • allow-internal: TCP/UDP/ICMP between VPC resources                       │
│  • allow-health-checks: GCP Load Balancer health checks                     │
│  • allow-ssh: IAP tunnel for secure SSH access                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ⚠️ Adaptations pour Projet Lab GCP

Ce code a été adapté pour fonctionner avec les **contraintes d'organisation** des projets lab GCP :

| Contrainte Org Policy | Problème | Solution appliquée |
|-----------------------|----------|-------------------|
| `gcp.resourceLocations` | Europe interdite | → Région `us-central1` |
| `custom.allowEssentialVPCFlowLogs` | Flow logs > 30% interdit | → `flow_sampling = 0.1` (10%) |
| `custom.denyCloudNATLogging` | NAT logging interdit | → Logging désactivé |
| `iam.serviceAccounts.create` | Création SA interdite | → Service Account commenté |
| `custom.allowedMaxDiskSize` | Disk > 50GB interdit | → `disk_size_gb = 20` |
| Quota SSD limité (250GB) | Cluster régional = 300GB | → Cluster **zonal** (1 node) |
| Maintenance policy | Fenêtre hebdo insuffisante | → `FREQ=DAILY` |

> 💡 **Note** : En production, réactivez ces features en décommentant le code approprié.

---

## 🔄 Quick Reset (Nouveau projet toutes les 3h)

Les projets lab GCP expirent toutes les 3 heures. Voici comment réinitialiser rapidement :

### ⚠️ Étape 0 : Réauthentification (OBLIGATOIRE)

> **Important** : Chaque nouveau projet lab = nouveau compte Google. Vous DEVEZ vous réauthentifier !

```bash
# 1. Révoquer TOUTES les authentifications de l'ancien projet
gcloud auth revoke --all

# 2. Se connecter avec le NOUVEAU compte (celui affiché dans la console lab)
gcloud auth login
# → Une fenêtre navigateur s'ouvre, connectez-vous avec le nouveau compte

# 3. Configurer les credentials pour Terraform
gcloud auth application-default login

# 4. Vérifier que vous êtes sur le bon projet
gcloud config get-value project
gcloud config get-value account
```

### Option 1 : Script automatique (recommandé) ⚡

```bash
cd infra/

# Récupérer le nouveau project_id
gcloud config get-value project
# Output: kkgcplabs01-XXX

# Lancer le script avec le nouveau project_id
./init.sh kkgcplabs01-XXX

# Le script fait automatiquement :
# ✅ Vérifie l'authentification
# ✅ Crée le bucket GCS
# ✅ Met à jour backend.tf
# ✅ Crée terraform.tfvars
# ✅ Initialise Terraform

# Déployer (~7 min)
terraform apply
```

### Option 2 : Manuel

```bash
cd infra/

# 1. Récupérer le nouveau project_id
PROJECT_ID=$(gcloud config get-value project)
echo "Project: $PROJECT_ID"

# 2. Créer le bucket
gcloud storage buckets create gs://${PROJECT_ID}-tf-state \
  --location=us-central1 \
  --uniform-bucket-level-access

# 3. Mettre à jour backend.tf (remplacer le bucket)
sed -i "s/bucket = \".*\"/bucket = \"${PROJECT_ID}-tf-state\"/" backend.tf

# 4. Créer terraform.tfvars depuis le template
sed "s/PROJECT_ID/${PROJECT_ID}/g" terraform.tfvars.example > terraform.tfvars

# 5. Réinitialiser Terraform
rm -rf .terraform
terraform init

# 6. Déployer
terraform apply
```

### 🚨 Erreur courante : "Permission denied"

Si vous voyez cette erreur :
```
kk_lab_user_XXXXX@kkgcplabsXX.com does not have storage.buckets.create access
```

**Cause** : Vous êtes encore authentifié avec l'ancien compte.

**Solution** :
```bash
gcloud auth revoke --all
gcloud auth login
gcloud auth application-default login
```

### 📋 Checklist nouveau projet

| Étape | Commande | Vérifié |
|-------|----------|---------|
| Révoquer ancien compte | `gcloud auth revoke --all` | ☐ |
| Login nouveau compte | `gcloud auth login` | ☐ |
| Application credentials | `gcloud auth application-default login` | ☐ |
| Vérifier projet | `gcloud config get-value project` | ☐ |
| Lancer init.sh | `./init.sh <PROJECT_ID>` | ☐ |
| Déployer | `terraform apply` | ☐ |

### Fichiers modifiés automatiquement

| Fichier | Variable | Exemple |
|---------|----------|---------|
| `backend.tf` | `bucket` | `kkgcplabs01-XXX-tf-state` |
| `terraform.tfvars` | `project_id` | `kkgcplabs01-XXX` |

---

## 🚀 Quick Start

### Prérequis

| Outil | Version | Installation |
|-------|---------|--------------|
| Google Cloud SDK | Latest | `curl https://sdk.cloud.google.com \| bash` |
| Terraform | >= 1.5.0 | `brew install terraform` ou [tfenv](https://github.com/tfutils/tfenv) |
| kubectl | Latest | `gcloud components install kubectl` |
| gke-gcloud-auth-plugin | Latest | `gcloud components install gke-gcloud-auth-plugin` |

### 1️⃣ Authentification GCP

```bash
# Se connecter à GCP
gcloud auth login
gcloud auth application-default login

# Vérifier le projet actuel
gcloud config get-value project

# Configurer le projet (si nécessaire)
gcloud config set project kkgcplabs01-009
```

### 2️⃣ Créer le bucket pour Terraform State

> ⚠️ **Important** : Le bucket doit être créé AVANT `terraform init`

```bash
# Créer le bucket GCS pour le state Terraform
gcloud storage buckets create gs://kkgcplabs01-009-tf-state \
  --project=kkgcplabs01-009 \
  --location=us-central1 \
  --uniform-bucket-level-access

# Activer le versioning (recommandé pour la récupération)
gcloud storage buckets update gs://kkgcplabs01-009-tf-state --versioning
```

### 3️⃣ Déploiement

```bash
cd infra/

# Initialiser Terraform (télécharge les providers, configure le backend)
terraform init

# Vérifier le plan d'exécution
terraform plan

# Appliquer l'infrastructure (~ 7-10 minutes pour GKE zonal)
terraform apply

# Répondre 'yes' pour confirmer
```

### 4️⃣ Connexion au cluster GKE

```bash
# Installer le plugin d'authentification (si pas déjà fait)
gcloud components install gke-gcloud-auth-plugin

# Ou via apt (Ubuntu/Debian)
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin

# Configurer la variable d'environnement
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

# Configurer kubectl (ATTENTION: cluster ZONAL, pas régional)
gcloud container clusters get-credentials platform-cluster \
  --zone us-central1-a \
  --project kkgcplabs01-009

# Vérifier la connexion
kubectl get nodes
kubectl cluster-info
```

---

## 📁 Structure du projet

```
infra/
├── main.tf                    # Orchestration principale + activation APIs
├── variables.tf               # Définition des variables d'entrée
├── outputs.tf                 # Outputs exportés (endpoints, commandes)
├── providers.tf               # Configuration providers GCP + Kubernetes
├── backend.tf                 # Backend GCS pour le state
├── versions.tf                # Contraintes de versions Terraform/providers
├── terraform.tfvars           # Valeurs des variables (ignoré par git)
├── terraform.tfvars.example   # Exemple de configuration
├── terraform.md               # 📚 Guide Terraform pour débutants
├── .terraform.lock.hcl        # Lock file des providers
└── modules/
    ├── network/               # 🌐 Module réseau
    │   ├── main.tf            #    VPC, Subnet, Cloud Router, NAT, Firewalls
    │   ├── variables.tf       #    Variables du module
    │   └── outputs.tf         #    Outputs (network_name, subnet_name, etc.)
    └── gke/                   # ☸️ Module GKE
        ├── main.tf            #    Cluster avec node pool intégré
        ├── variables.tf       #    Variables du module
        └── outputs.tf         #    Outputs (cluster_endpoint, etc.)
```

---

## ⚙️ Configuration

### Variables principales

| Variable | Description | Valeur actuelle |
|----------|-------------|-----------------|
| `project_id` | ID du projet GCP | `kkgcplabs01-009` |
| `region` | Région GCP | `us-central1` |
| `zone` | Zone GCP (cluster zonal) | `us-central1-a` |
| `environment` | Environnement | `dev` |
| `cluster_name` | Nom du cluster GKE | `platform-cluster` |
| `node_count` | Nombre de nœuds | `1` |
| `machine_type` | Type de machine | `e2-medium` |
| `disk_size_gb` | Taille disque | `20 GB` |

### Configuration réseau

| Paramètre | CIDR | Usage |
|-----------|------|-------|
| Subnet primaire | `10.0.0.0/20` | Nœuds GKE |
| Pods (secondary) | `10.16.0.0/14` | ~262k IPs pour pods |
| Services (secondary) | `10.20.0.0/20` | ~4k IPs pour services K8s |
| Master CIDR | `172.16.0.0/28` | Control plane privé |

### Cluster Zonal vs Régional

| Aspect | Zonal (actuel) | Régional |
|--------|---------------|----------|
| Haute disponibilité | ❌ Single zone | ✅ Multi-zone |
| Coût | 💰 Moins cher | 💰💰💰 3x nodes |
| Quota SSD | ✅ ~100GB | ❌ ~300GB (dépassé) |
| Use case | Dev/POC | Production |

---

## 🔐 Sécurité

### Workload Identity

Le cluster utilise **Workload Identity** pour une authentification sécurisée aux services GCP :

```yaml
# Exemple: Lier un ServiceAccount K8s à un ServiceAccount GCP
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: MY_SA@kkgcplabs01-009.iam.gserviceaccount.com
```

> ⚠️ **Note Lab** : La création de Service Accounts GCP est désactivée dans ce projet lab. Utilisez le default compute SA ou créez manuellement.

### Private Cluster

| Feature | Configuration |
|---------|---------------|
| Nœuds privés | ✅ Pas d'IP publique |
| Endpoint public | ✅ API accessible (avec authorized networks) |
| Cloud NAT | ✅ Accès internet sortant (logging désactivé) |
| IAP Tunnel | ✅ SSH sécurisé vers les nœuds |

### Network Policies

Calico est activé pour les NetworkPolicies Kubernetes :

```yaml
# Exemple: Isoler un namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## 📊 Outputs Terraform

| Output | Description | Valeur |
|--------|-------------|--------|
| `cluster_name` | Nom du cluster | `platform-cluster` |
| `cluster_location` | Zone du cluster | `us-central1-a` |
| `cluster_endpoint` | Endpoint API (sensible) | `https://x.x.x.x` |
| `gke_connect_command` | Commande kubectl | `gcloud container clusters get-credentials...` |
| `workload_identity_pool` | Pool WI | `kkgcplabs01-009.svc.id.goog` |
| `network_name` | Nom du VPC | `platform-vpc` |
| `subnet_name` | Nom du subnet | `platform-vpc-subnet` |

```bash
# Afficher tous les outputs
terraform output

# Afficher un output spécifique
terraform output gke_connect_command
```

---

## 💰 Estimation des coûts

| Ressource | Spécification | Coût estimé/mois |
|-----------|---------------|------------------|
| GKE Cluster | Management fee | ~$72 |
| Node (1x e2-medium) | Zonal, 1 node | ~$25 |
| Cloud NAT | Gateway + data | ~$10-30 |
| Persistent Disk | 20GB | ~$1 |
| **Total estimé** | | **~$110-130/mois** |

> 💡 Le cluster zonal réduit les coûts de ~40% par rapport au régional.

---

## 🔧 Commandes utiles

### Terraform

```bash
# Formater le code
terraform fmt -recursive

# Valider la syntaxe
terraform validate

# Voir l'état actuel
terraform state list

# Rafraîchir l'état
terraform refresh

# Détruire le cluster seulement
terraform destroy -target=module.gke
```

### GKE / kubectl

```bash
# Infos cluster
kubectl cluster-info
kubectl get nodes -o wide

# Vérifier les composants système
kubectl get pods -n kube-system

# Voir les events
kubectl get events --sort-by='.lastTimestamp'
```

### Debugging

```bash
# Logs Terraform détaillés
TF_LOG=DEBUG terraform plan

# Vérifier l'état du cluster GKE (ZONAL)
gcloud container clusters describe platform-cluster \
  --zone us-central1-a \
  --format="table(status,currentNodeCount,currentMasterVersion)"

# Vérifier les opérations en cours
gcloud container operations list --filter="status!=DONE"
```

---

## 🚨 Troubleshooting

### Erreur: "bucket does not exist"

```bash
gcloud storage buckets create gs://kkgcplabs01-009-tf-state \
  --project=kkgcplabs01-009 \
  --location=us-central1 \
  --uniform-bucket-level-access
```

### Erreur: "gke-gcloud-auth-plugin not found"

```bash
# Installer le plugin
gcloud components install gke-gcloud-auth-plugin

# Ou via apt
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin

# Configurer la variable
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
echo 'export USE_GKE_GCLOUD_AUTH_PLUGIN=True' >> ~/.bashrc
```

### Erreur: "VPC Flow logs policy"

Le sampling rate doit être < 30%. Déjà corrigé : `flow_sampling = 0.1`

### Erreur: "Cloud NAT logging not allowed"

Le logging NAT est désactivé dans le code pour respecter la policy.

### Erreur: "Maximum disk size is 50GB"

Utiliser `disk_size_gb = 20` (ou max 50). Déjà configuré.

### Erreur: "SSD quota exceeded"

Utiliser un cluster zonal (1 zone) au lieu de régional (3 zones). Déjà configuré avec `zone = "us-central1-a"`.

### Erreur: "Permission denied to create service account"

La création de SA est commentée. Utilisez le default compute SA.

---

## 🧹 Nettoyage

```bash
# ⚠️ ATTENTION: Détruit TOUTES les ressources !
terraform destroy

# Supprimer aussi le bucket state (optionnel)
gcloud storage rm -r gs://kkgcplabs01-009-tf-state
```

---

## 📚 Ressources

- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Private GKE Clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)
- [VPC-native Clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)

---

## ➡️ Prochaines étapes

Une fois l'infrastructure déployée :

1. **BRIQUE 2** — GitOps avec FluxCD
2. **BRIQUE 3** — Crossplane pour le provisioning cloud
3. **BRIQUE 4** — Microservice + CI/CD
4. **BRIQUE 5** — Observabilité + Developer Experience
