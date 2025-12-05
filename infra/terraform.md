# 📚 Terraform pour Débutants

> Guide pédagogique basé sur la Brique 1 du POC Platform Engineer

## 🎯 Qu'est-ce que Terraform ?

**Terraform** est un outil d'**Infrastructure as Code (IaC)** développé par HashiCorp. Il permet de :

- ✅ Décrire son infrastructure dans des fichiers texte (`.tf`)
- ✅ Versionner son infrastructure avec Git
- ✅ Reproduire exactement la même infrastructure à chaque déploiement
- ✅ Gérer le cycle de vie complet : création, modification, destruction

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Code .tf      │────▶│    Terraform    │────▶│  Infrastructure │
│ (déclaratif)    │     │    (moteur)     │     │     (GCP)       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 📁 Structure des fichiers Terraform

Dans notre projet, voici comment les fichiers sont organisés :

```
infra/
├── versions.tf          # 1️⃣ Versions requises
├── providers.tf         # 2️⃣ Configuration des providers
├── backend.tf           # 3️⃣ Stockage de l'état
├── variables.tf         # 4️⃣ Définition des variables
├── terraform.tfvars     # 5️⃣ Valeurs des variables
├── main.tf              # 6️⃣ Ressources principales
├── outputs.tf           # 7️⃣ Sorties
└── modules/             # 8️⃣ Modules réutilisables
    ├── network/
    └── gke/
```

> 💡 **Convention** : Terraform lit TOUS les fichiers `.tf` du dossier. La séparation en fichiers est pour l'organisation humaine, pas technique.

---

## 1️⃣ versions.tf — Contraintes de versions

Ce fichier définit les versions minimales requises :

```hcl
terraform {
  required_version = ">= 1.5.0"    # Version de Terraform CLI

  required_providers {
    google = {
      source  = "hashicorp/google"  # Où trouver le provider
      version = "~> 5.0"            # Version compatible
    }
  }
}
```

### Comprendre les contraintes de version

| Syntaxe | Signification | Exemple |
|---------|---------------|---------|
| `= 1.5.0` | Exactement cette version | `1.5.0` uniquement |
| `>= 1.5.0` | Cette version ou supérieure | `1.5.0`, `1.6.0`, `2.0.0`... |
| `~> 1.5.0` | Compatible (patch autorisé) | `1.5.0`, `1.5.9` mais pas `1.6.0` |
| `~> 1.5` | Compatible (minor autorisé) | `1.5.0`, `1.9.9` mais pas `2.0.0` |

---

## 2️⃣ providers.tf — Les providers

Un **provider** est un plugin qui permet à Terraform de communiquer avec une API (GCP, AWS, Azure...).

```hcl
provider "google" {
  project = var.project_id    # Utilise une variable
  region  = var.region        # Utilise une variable
}
```

### Providers utilisés dans notre projet

| Provider | Rôle |
|----------|------|
| `google` | Créer des ressources GCP (VPC, GKE...) |
| `google-beta` | Accès aux features GCP en beta |
| `kubernetes` | Interagir avec le cluster K8s |

---

## 3️⃣ backend.tf — Le State (État)

Le **state** est le cœur de Terraform. C'est un fichier JSON qui mémorise :
- Ce que Terraform a créé
- Les IDs des ressources dans le cloud
- Les dépendances entre ressources

```hcl
terraform {
  backend "gcs" {
    bucket = "kkgcplabs01-009-tf-state"  # Bucket GCS
    prefix = "terraform/state"            # Chemin dans le bucket
  }
}
```

### Pourquoi un backend distant ?

```
❌ Backend local (terraform.tfstate)
   └── Un seul développeur peut travailler
   └── Risque de perte si le fichier est supprimé
   └── Pas de verrouillage concurrent

✅ Backend GCS (Google Cloud Storage)
   └── Équipe peut collaborer
   └── État sauvegardé et versionné
   └── Verrouillage automatique (state locking)
```

---

## 4️⃣ variables.tf — Définition des variables

Les variables rendent le code réutilisable et configurable :

```hcl
variable "project_id" {
  description = "The GCP project ID"    # Documentation
  type        = string                  # Type de donnée
  # Pas de default = variable obligatoire
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"           # Valeur par défaut
}

variable "zone" {
  description = "The GCP zone for zonal cluster"
  type        = string
  default     = "us-central1-a"         # Cluster zonal pour économiser les quotas
}

variable "node_count" {
  description = "Number of nodes"
  type        = number                  # Type numérique
  default     = 1
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)             # Type map (dictionnaire)
  default = {
    managed_by = "terraform"
  }
}
```

### Types de variables disponibles

| Type | Exemple | Usage |
|------|---------|-------|
| `string` | `"hello"` | Texte |
| `number` | `42` | Nombres |
| `bool` | `true` / `false` | Booléens |
| `list(string)` | `["a", "b", "c"]` | Listes |
| `map(string)` | `{key = "value"}` | Dictionnaires |
| `object({...})` | Structure complexe | Objets typés |

---

## 5️⃣ terraform.tfvars — Valeurs des variables

Ce fichier contient les **valeurs** des variables :

```hcl
# terraform.tfvars
project_id   = "kkgcplabs01-009"
region       = "us-central1"
zone         = "us-central1-a"    # Cluster zonal pour respecter les quotas
cluster_name = "platform-cluster"
node_count   = 1
disk_size_gb = 20                 # Max 50GB selon org policy

labels = {
  managed_by = "terraform"
  project    = "platform-engineer-poc"
}
```

### Ordre de priorité des variables

Terraform charge les variables dans cet ordre (le dernier gagne) :

```
1. default dans variables.tf       (priorité la plus basse)
2. terraform.tfvars
3. *.auto.tfvars
4. -var-file="custom.tfvars"
5. -var="key=value"
6. TF_VAR_key=value (env)          (priorité la plus haute)
```

---

## 6️⃣ main.tf — Les ressources

C'est ici qu'on déclare ce qu'on veut créer :

```hcl
# Syntaxe générale
resource "TYPE_RESSOURCE" "NOM_LOCAL" {
  argument1 = "valeur"
  argument2 = var.ma_variable
}
```

### Exemple concret : activer une API GCP

```hcl
resource "google_project_service" "required_apis" {
  for_each = toset([                    # Boucle for_each
    "compute.googleapis.com",
    "container.googleapis.com",
    # APIs commentées car permissions limitées dans projet lab
    # "cloudresourcemanager.googleapis.com",
    # "iam.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value       # Valeur courante de la boucle
  disable_on_destroy = false
}
```

### Exemple : appeler un module

```hcl
module "network" {
  source = "./modules/network"          # Chemin vers le module

  # Passer des variables au module
  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name

  # Dépendance explicite
  depends_on = [google_project_service.required_apis]
}

module "gke" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  zone         = var.zone              # Variable zone pour cluster zonal
  cluster_name = var.cluster_name
  # ...

  depends_on = [module.network]
}
```

---

## 7️⃣ outputs.tf — Les sorties

Les outputs permettent d'**exporter** des valeurs après le déploiement :

```hcl
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = module.gke.cluster_endpoint
  sensitive   = true                    # Masque la valeur dans les logs
}

output "gke_connect_command" {
  description = "Command to configure kubectl"
  # Note: utilise zone pour cluster zonal, pas region
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${var.zone}"
}
```

### Utiliser les outputs

```bash
# Afficher tous les outputs
terraform output

# Afficher un output spécifique
terraform output cluster_name

# Format JSON (pour scripts)
terraform output -json
```

---

## 8️⃣ Modules — Code réutilisable

Un **module** est un ensemble de ressources Terraform packagées ensemble.

### Structure d'un module

```
modules/network/
├── main.tf          # Ressources du module
├── variables.tf     # Inputs du module
└── outputs.tf       # Outputs du module
```

### Exemple : Module Network (adapté pour projet lab)

**variables.tf** (inputs)
```hcl
variable "network_name" {
  type = string
}

variable "subnet_cidr" {
  type = string
}
```

**main.tf** (ressources)
```hcl
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  # VPC Flow Logs - sampling réduit pour org policy (< 30%)
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.1  # 10% au lieu de 50%
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.network_name}-nat"
  router = google_compute_router.router.name
  # ...

  # NAT logging désactivé (org policy)
  # log_config {
  #   enable = true
  #   filter = "ERRORS_ONLY"
  # }
}
```

### Exemple : Module GKE (avec node pool intégré)

```hcl
resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  project  = var.project_id
  
  # Cluster ZONAL pour économiser les quotas SSD
  location = var.zone != null ? var.zone : var.region

  # Node pool INTÉGRÉ (pas remove_default_node_pool)
  # Évite la création d'un pool temporaire avec disk 100GB
  initial_node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb  # 20GB (max 50GB selon org policy)
    disk_type    = "pd-standard"
    # ...
  }

  # Maintenance daily (requis par GKE)
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=DAILY"  # Pas WEEKLY (insuffisant)
    }
  }

  deletion_protection = false
}

# Service Account commenté (permission IAM interdite dans lab)
# resource "google_service_account" "workload_identity_sa" { ... }
```

---

## 🔄 Cycle de vie Terraform

### Les 4 commandes essentielles

```bash
# 1. INIT - Initialiser le projet
terraform init
# └── Télécharge les providers
# └── Configure le backend
# └── Initialise les modules

# 2. PLAN - Prévisualiser les changements
terraform plan
# └── Compare l'état actuel vs la configuration
# └── Affiche ce qui sera créé/modifié/détruit

# 3. APPLY - Appliquer les changements
terraform apply
# └── Exécute le plan
# └── Met à jour le state

# 4. DESTROY - Détruire l'infrastructure
terraform destroy
# └── Supprime toutes les ressources gérées
```

### Visualisation du flux

```
┌─────────┐    ┌──────────┐    ┌─────────────┐    ┌─────────┐
│  .tf    │───▶│   PLAN   │───▶│   APPLY     │───▶│  Cloud  │
│ fichiers│    │(preview) │    │ (exécution) │    │  (GCP)  │
└─────────┘    └──────────┘    └─────────────┘    └─────────┘
                                      │
                                      ▼
                              ┌─────────────┐
                              │    STATE    │
                              │ (tfstate)   │
                              └─────────────┘
```

---

## 📖 Concepts clés

### Interpolation

Insérer des valeurs dynamiques avec `${}` :

```hcl
name = "${var.project_name}-${var.environment}"
# Résultat : "platform-dev"
```

### Références entre ressources

Accéder aux attributs d'autres ressources :

```hcl
# Référencer une ressource
network = google_compute_network.vpc.id

# Référencer un output de module
subnet_name = module.network.subnet_name

# Référencer une data source
project = data.google_project.current.project_id
```

### Dépendances

**Implicites** (automatiques) :
```hcl
resource "google_compute_subnetwork" "subnet" {
  network = google_compute_network.vpc.id  # Terraform sait que VPC doit exister d'abord
}
```

**Explicites** (manuelles) :
```hcl
module "gke" {
  source = "./modules/gke"
  
  depends_on = [module.network]  # Force l'ordre
}
```

### Boucles

**for_each** (recommandé) :
```hcl
resource "google_project_service" "apis" {
  for_each = toset(["compute.googleapis.com", "container.googleapis.com"])
  service  = each.value
}
```

**count** (pour le nombre) :
```hcl
resource "google_compute_instance" "server" {
  count = var.instance_count
  name  = "server-${count.index}"
}
```

### Conditions

```hcl
# Opérateur ternaire
enable_feature = var.environment == "prod" ? true : false

# Créer conditionnellement
resource "google_compute_instance" "bastion" {
  count = var.create_bastion ? 1 : 0  # 0 = pas créé
}

# Choisir zone ou région
location = var.zone != null ? var.zone : var.region
```

---

## 🛠️ Commandes utiles

```bash
# Formater le code
terraform fmt -recursive

# Valider la syntaxe
terraform validate

# Voir l'état
terraform state list
terraform state show module.network.google_compute_network.vpc

# Importer une ressource existante
terraform import google_compute_network.vpc projects/PROJECT/global/networks/VPC_NAME

# Voir les providers installés
terraform providers

# Mettre à jour les providers
terraform init -upgrade

# Détruire une ressource spécifique
terraform destroy -target=module.gke
```

---

## 🎓 Exercices pratiques

### Exercice 1 : Comprendre les fichiers

1. Ouvrez `infra/variables.tf`
2. Trouvez la variable `cluster_name`
3. Quelle est sa valeur par défaut ?
4. Où est-elle utilisée ? (cherchez `var.cluster_name`)

### Exercice 2 : Comprendre les adaptations lab

1. Ouvrez `infra/modules/network/main.tf`
2. Trouvez `flow_sampling` - pourquoi est-ce 0.1 et pas 0.5 ?
3. Trouvez `log_config` dans NAT - pourquoi est-ce commenté ?

### Exercice 3 : Modifier une variable

1. Dans `terraform.tfvars`, changez `node_count = 2`
2. Lancez `terraform plan`
3. Que va faire Terraform ?

### Exercice 4 : Explorer le state

```bash
# Lister toutes les ressources
terraform state list

# Voir les détails du VPC
terraform state show module.network.google_compute_network.vpc

# Voir le cluster GKE
terraform state show module.gke.google_container_cluster.cluster
```

---

## 🚨 Leçons apprises : Contraintes Org Policy

Dans un projet GCP avec des **Organization Policies** restrictives, voici les erreurs courantes et solutions :

| Erreur | Cause | Solution |
|--------|-------|----------|
| `resource location constraint` | Région interdite | Utiliser `us-central1` |
| `VPC Flow logs policy` | Sampling > 30% | `flow_sampling = 0.1` |
| `Cloud NAT logging not allowed` | Policy stricte | Commenter `log_config` |
| `Permission denied serviceAccounts.create` | IAM restreint | Commenter SA creation |
| `Maximum disk size is 50GB` | Quota disque | `disk_size_gb = 20` |
| `SSD quota exceeded` | 250GB max, cluster régional = 300GB | Cluster **zonal** |
| `Maintenance policy invalid` | Fenêtre hebdo insuffisante | `FREQ=DAILY` |

> 💡 **Conseil** : Toujours vérifier les org policies avant de déployer :
> ```bash
> gcloud resource-manager org-policies list --project=PROJECT_ID
> ```

---

## 📚 Ressources pour aller plus loin

| Ressource | Lien |
|-----------|------|
| Documentation officielle | https://developer.hashicorp.com/terraform/docs |
| Terraform Registry | https://registry.terraform.io |
| Google Provider | https://registry.terraform.io/providers/hashicorp/google |
| Terraform Best Practices | https://www.terraform-best-practices.com |
| Learn Terraform (gratuit) | https://developer.hashicorp.com/terraform/tutorials |

---

## 🗺️ Récapitulatif de notre infrastructure

```hcl
# Ce que notre code Terraform crée :

# 1. Activation des APIs GCP (limitées dans projet lab)
google_project_service.required_apis["compute.googleapis.com"]
google_project_service.required_apis["container.googleapis.com"]

# 2. Module Network
module.network.google_compute_network.vpc              # VPC
module.network.google_compute_subnetwork.subnet        # Subnet (flow_sampling=0.1)
module.network.google_compute_router.router            # Cloud Router
module.network.google_compute_router_nat.nat           # Cloud NAT (no logging)
module.network.google_compute_firewall.allow_internal  # Firewall rules
module.network.google_compute_firewall.allow_health_checks
module.network.google_compute_firewall.allow_ssh

# 3. Module GKE
module.gke.google_container_cluster.cluster            # Cluster GKE ZONAL
# └── default-pool intégré (disk=20GB, node_count=1)
# └── Workload Identity activé
# └── Calico network policy
# └── Managed Prometheus
```

---

> 💡 **Conseil** : La meilleure façon d'apprendre Terraform est de **lire le code** et de **lancer des plans**. N'ayez pas peur d'expérimenter avec `terraform plan` - ça ne modifie rien !

> ⚠️ **Note** : Ce code est adapté pour un projet lab GCP avec des restrictions. En production, réactivez les features commentées (NAT logging, Service Accounts, etc.)
