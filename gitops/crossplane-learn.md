# 📚 Crossplane - Guide Pédagogique Complet

> **BRIQUE 3** - Comprendre Crossplane de A à Z

Ce document explique en détail **pourquoi** Crossplane existe, **comment** il fonctionne, et **ce qui a été implémenté** dans ce POC.

---

## 🎯 Table des matières

1. [Le problème que Crossplane résout](#le-problème-que-crossplane-résout)
2. [Qu'est-ce que Crossplane ?](#quest-ce-que-crossplane)
3. [Architecture et concepts](#architecture-et-concepts)
4. [Workflow complet](#workflow-complet)
5. [Ce qui a été implémenté](#ce-qui-a-été-implémenté)
6. [Cheminement détaillé](#cheminement-détaillé)

---

## 🚨 Le problème que Crossplane résout

### Scénario traditionnel (sans Crossplane)

Imaginez que vous êtes développeur et que votre application a besoin d'une base de données PostgreSQL :

```
┌─────────────────────────────────────────────────────────────────┐
│                    DÉVELOPPEUR                                   │
│  "J'ai besoin d'une DB PostgreSQL pour mon app"                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TICKET JIRA / SLACK                           │
│  "Demande: Créer une base de données PostgreSQL"                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              ÉQUIPE PLATFORM / INFRA                             │
│  1. Analyser la demande                                          │
│  2. Écrire du Terraform                                          │
│  3. Code review                                                  │
│  4. terraform apply                                              │
│  5. Créer manuellement le Secret K8s avec les credentials        │
│  6. Notifier le développeur                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ⏱️ DÉLAI : 2-5 jours
```

**Problèmes** :
- ❌ **Délai long** : Le développeur attend
- ❌ **Friction** : Ticket → Review → Apply → Notification
- ❌ **Dépendance** : Le dev dépend de l'équipe Platform
- ❌ **Incohérence** : Terraform pour infra, YAML pour K8s

### Scénario avec Crossplane

```
┌─────────────────────────────────────────────────────────────────┐
│                    DÉVELOPPEUR                                   │
│  Crée un fichier YAML dans Git :                                 │
│                                                                  │
│  apiVersion: database.platform.acme.com/v1                      │
│  kind: PostgresDatabase                                          │
│  metadata:                                                       │
│    name: my-app-db                                               │
│  spec:                                                           │
│    size: medium                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼ git push
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXCD (GitOps)                               │
│  Détecte le nouveau fichier → Sync vers le cluster              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CROSSPLANE                                    │
│  Lit le YAML → Crée la DB sur GCP → Crée le Secret K8s          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ⏱️ DÉLAI : 2-5 minutes
```

**Avantages** :
- ✅ **Rapidité** : Self-service en quelques minutes
- ✅ **Uniformité** : Tout est du YAML Kubernetes
- ✅ **GitOps natif** : Fonctionne parfaitement avec FluxCD
- ✅ **Automatisation** : Pas d'intervention manuelle

---

## 🔮 Qu'est-ce que Crossplane ?

### Définition simple

**Crossplane** est un **contrôleur Kubernetes** qui permet de **créer des ressources cloud** (bases de données, buckets, VMs, etc.) en utilisant des **fichiers YAML**, exactement comme vous créez des Pods ou Services.

### Analogie

Imaginez Kubernetes comme un **restaurant** :

| Concept | Restaurant | Kubernetes |
|---------|------------|------------|
| **Menu** | Plats disponibles | Ressources K8s (Pods, Services) |
| **Commande** | "Je veux une pizza" | `kubectl apply -f pod.yaml` |
| **Cuisine** | Le chef prépare | Kubernetes crée le Pod |

**Crossplane** ajoute des **plats externes** au menu :

| Concept | Restaurant | Crossplane |
|---------|------------|------------|
| **Menu étendu** | Plats du restaurant + plats d'autres restaurants | Ressources K8s + Ressources Cloud |
| **Commande** | "Je veux une pizza + un dessert du restaurant d'à côté" | `kubectl apply -f bucket.yaml` |
| **Cuisine** | Le chef commande au restaurant d'à côté | Crossplane crée le bucket sur GCP |

### En termes techniques

Crossplane est un **Kubernetes Controller** qui :
1. **Observe** les ressources Custom (ex: `Bucket`, `CloudSQLInstance`)
2. **Réconcilie** : Compare l'état désiré (YAML) avec l'état réel (GCP)
3. **Crée/Met à jour/Supprime** les ressources cloud via les APIs GCP

---

## 🏗️ Architecture et concepts

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                     GIT REPOSITORY                              │
│                                                                  │
│   gitops/apps/examples/                                          │
│   └── gcs-bucket-example.yaml  ◄─── Développeur crée ce fichier│
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼ git push
┌─────────────────────────────────────────────────────────────────┐
│                      FLUXCD                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  source-controller : Lit Git                               │  │
│  │  kustomize-controller : Applique les manifests            │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼ sync
┌─────────────────────────────────────────────────────────────────┐
│                  KUBERNETES CLUSTER                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  namespace: default                                        │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  apiVersion: storage.gcp.upbound.io/v1beta1          │ │  │
│  │  │  kind: Bucket                                         │ │  │
│  │  │  metadata:                                            │ │  │
│  │  │    name: my-bucket                                    │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  namespace: crossplane-system                            │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  CROSSPLANE CONTROLLER                                │ │  │
│  │  │  "Je vois un Bucket, je dois le créer sur GCP"       │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                             │                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  PROVIDER GCP                                          │ │  │
│  │  │  "Je sais comment parler à l'API GCP"                 │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  │                             │                             │  │
│  │  ┌──────────────────────────────────────────────────────┐ │  │
│  │  │  PROVIDERCONFIG                                       │ │  │
│  │  │  "Voici comment m'authentifier (Workload Identity)"  │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────┬──────────────────────────────┘  │
│                                │                                  │
└────────────────────────────────┼──────────────────────────────────┘
                                 │
                                 ▼ API GCP
┌─────────────────────────────────────────────────────────────────┐
│                      GOOGLE CLOUD                                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cloud Storage                                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Bucket: my-bucket                                  │  │  │
│  │  │  Location: US-CENTRAL1                              │  │  │
│  │  │  Created by: Crossplane                            │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Concepts clés

#### 1. **Provider**

Un **Provider** est un plugin qui permet à Crossplane de parler à un cloud spécifique.

```yaml
# Provider GCP
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp
spec:
  package: xpkg.upbound.io/upbound/provider-gcp:v0.47.0
```

**Analogie** : C'est comme un **driver** pour une imprimante. Le Provider GCP "sait" comment créer des buckets, des CloudSQL, etc.

#### 2. **ProviderConfig**

Le **ProviderConfig** configure l'authentification du Provider.

```yaml
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: kkgcplabs01-032
  credentials:
    source: InjectedIdentity  # Workload Identity
```

**Analogie** : C'est comme les **identifiants** pour se connecter à GCP. "Voici mon projet, voici comment je m'authentifie".

#### 3. **Managed Resource**

Une **Managed Resource** est une ressource cloud que Crossplane peut créer.

```yaml
apiVersion: storage.gcp.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-bucket
spec:
  forProvider:
    location: US-CENTRAL1
```

**Analogie** : C'est comme une **commande** au restaurant. "Je veux un bucket GCS avec ces spécifications".

#### 4. **Composition** (avancé)

Une **Composition** est un template qui combine plusieurs ressources.

**Exemple** : Au lieu de créer manuellement CloudSQL + Secret + ServiceAccount, vous créez un template "PostgresDatabase" qui fait tout automatiquement.

---

## 🔄 Workflow complet

### Étape par étape : Créer un Bucket GCS

#### Étape 1 : Le développeur crée le fichier YAML

```yaml
# gitops/apps/examples/my-bucket.yaml
apiVersion: storage.gcp.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-app-bucket
  namespace: default
spec:
  forProvider:
    location: US-CENTRAL1
    storageClass: STANDARD
```

#### Étape 2 : Git push

```bash
git add gitops/apps/examples/my-bucket.yaml
git commit -m "feat: add GCS bucket for my app"
git push
```

#### Étape 3 : FluxCD détecte le changement

```
FluxCD source-controller :
  "Nouveau commit détecté !"
    ↓
FluxCD kustomize-controller :
  "Je dois appliquer les nouveaux manifests"
    ↓
kubectl apply -f my-bucket.yaml
```

#### Étape 4 : Kubernetes crée la ressource

```bash
# La ressource Bucket est créée dans etcd
kubectl get bucket my-app-bucket
# NAME            READY   SYNCED   EXTERNAL-NAME
# my-app-bucket   False   False
```

#### Étape 5 : Crossplane détecte la ressource

```
Crossplane Controller :
  "Je vois un Bucket qui n'est pas encore créé sur GCP"
    ↓
"Je dois le créer via le Provider GCP"
```

#### Étape 6 : Crossplane s'authentifie

```
ProviderConfig :
  "Je dois m'authentifier avec Workload Identity"
    ↓
ServiceAccount Kubernetes (crossplane) :
  "J'ai l'annotation iam.gke.io/gcp-service-account"
    ↓
Workload Identity :
  "Je suis lié au Service Account GCP crossplane-sa@..."
    ↓
API GCP :
  "Authentification OK, vous pouvez créer des ressources"
```

#### Étape 7 : Crossplane crée le bucket sur GCP

```
Provider GCP :
  POST https://storage.googleapis.com/storage/v1/b
  {
    "name": "my-app-bucket",
    "location": "US-CENTRAL1",
    "storageClass": "STANDARD"
  }
    ↓
GCP :
  "Bucket créé avec succès !"
    ↓
Crossplane :
  "Je mets à jour le statut de la ressource Bucket"
```

#### Étape 8 : Réconciliation continue

```
Toutes les 60 secondes, Crossplane vérifie :
  "Le bucket existe-t-il toujours sur GCP ?"
    ↓
Si oui : ✅ Tout est OK
Si non : 🔄 Crossplane le recrée automatiquement (self-healing)
```

---

## 🛠️ Ce qui a été implémenté

### 1. Infrastructure Terraform

#### Service Account GCP

```hcl
# infra/main.tf
resource "google_service_account" "crossplane" {
  account_id   = "crossplane-sa"
  display_name = "Crossplane Service Account"
}
```

**Pourquoi** : Crossplane a besoin d'un compte de service GCP pour créer des ressources.

#### Permissions IAM

```hcl
resource "google_project_iam_member" "crossplane_storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.crossplane.email}"
}
```

**Pourquoi** : Crossplane doit avoir les permissions pour créer des buckets, bases de données, etc.

#### Workload Identity Binding

```hcl
resource "google_service_account_iam_member" "crossplane_workload_identity" {
  service_account_id = google_service_account.crossplane.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[crossplane-system/crossplane]"
}
```

**Pourquoi** : Permet au ServiceAccount Kubernetes `crossplane` dans `crossplane-system` d'utiliser le ServiceAccount GCP sans clés.

### 2. Configuration Kubernetes

#### Namespace

```yaml
# gitops/infrastructure/controllers/crossplane/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: crossplane-system
```

**Pourquoi** : Isolation des ressources Crossplane.

#### ServiceAccount Kubernetes

```yaml
# gitops/infrastructure/controllers/crossplane/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: crossplane
  namespace: crossplane-system
  annotations:
    iam.gke.io/gcp-service-account: crossplane-sa@PROJECT_ID.iam.gserviceaccount.com
```

**Pourquoi** : L'annotation `iam.gke.io/gcp-service-account` active Workload Identity.

#### HelmRelease Crossplane

```yaml
# gitops/infrastructure/controllers/crossplane/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: crossplane
spec:
  chart:
    spec:
      chart: crossplane
      version: "1.*"
```

**Pourquoi** : Installe Crossplane via Helm (géré par FluxCD).

#### Provider GCP

```yaml
# gitops/infrastructure/controllers/crossplane/provider-gcp.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp
spec:
  package: xpkg.upbound.io/upbound/provider-gcp:v0.47.0
```

**Pourquoi** : Ajoute le support GCP à Crossplane.

#### ProviderConfig

```yaml
# gitops/infrastructure/controllers/crossplane/providerconfig-gcp.yaml
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: PROJECT_ID
  credentials:
    source: InjectedIdentity
```

**Pourquoi** : Configure l'authentification GCP via Workload Identity.

### 3. Script d'automatisation

```bash
# infra/update-crossplane-config.sh
# Met à jour automatiquement les placeholders après terraform apply
```

**Pourquoi** : Évite de mettre à jour manuellement le project_id et l'email du ServiceAccount.

---

## 🗺️ Cheminement détaillé

### Phase 1 : Préparation (Terraform)

```
1. Développeur modifie infra/main.tf
   └─> Ajoute les ressources Crossplane (SA, IAM, Workload Identity)

2. terraform plan
   └─> Vérifie ce qui sera créé

3. terraform apply
   └─> Crée :
       ├─ Service Account GCP (crossplane-sa@...)
       ├─ Permissions IAM (storage.admin, sql.admin, pubsub.admin)
       └─ Workload Identity Binding

4. terraform output
   └─> Affiche :
       ├─ crossplane_service_account_email
       └─ project_id

5. ./update-crossplane-config.sh
   └─> Met à jour :
       ├─ providerconfig-gcp.yaml (projectID)
       └─ serviceaccount.yaml (annotation iam.gke.io)
```

### Phase 2 : Déploiement (FluxCD)

```
6. git add + commit + push
   └─> Les fichiers Crossplane sont dans Git

7. FluxCD détecte les changements
   └─> source-controller : "Nouveau commit !"
   └─> kustomize-controller : "Je dois appliquer"

8. Kubernetes crée les ressources
   └─> Namespace crossplane-system
   └─> ServiceAccount crossplane (avec annotation)
   └─> HelmRelease crossplane
   └─> Provider provider-gcp
   └─> ProviderConfig default

9. Helm installe Crossplane
   └─> Chart crossplane déployé
   └─> Pods crossplane créés

10. Provider GCP s'installe
    └─> Provider package téléchargé
    └─> CRDs créés (Bucket, CloudSQLInstance, etc.)
```

### Phase 3 : Vérification

```
11. Vérifier l'installation
    kubectl get pods -n crossplane-system
    └─> crossplane-xxx : Running ✅

12. Vérifier le Provider
    kubectl get provider provider-gcp
    └─> INSTALLED ✅

13. Vérifier le ProviderConfig
    kubectl get providerconfig default
    └─> READY ✅

14. Vérifier l'authentification
    kubectl get serviceaccount crossplane -n crossplane-system -o yaml
    └─> Annotation iam.gke.io présente ✅
```

### Phase 4 : Utilisation

```
15. Développeur crée un Bucket
    └─> Fichier YAML dans gitops/apps/examples/

16. Git push
    └─> FluxCD sync

17. Bucket créé dans Kubernetes
    kubectl get bucket my-bucket
    └─> READY: False (en cours de création)

18. Crossplane crée le bucket sur GCP
    └─> Appel API GCP
    └─> Bucket créé sur Cloud Storage

19. Statut mis à jour
    kubectl get bucket my-bucket
    └─> READY: True ✅
    └─> EXTERNAL-NAME: my-bucket ✅
```

---

## 📊 Résumé visuel du cheminement

```
┌─────────────────────────────────────────────────────────────────┐
│                    TERRAFORM                                     │
│  infra/main.tf                                                   │
│  ├─ Service Account GCP                                          │
│  ├─ IAM Roles                                                    │
│  └─ Workload Identity Binding                                    │
│                                                                  │
│  terraform apply                                                 │
│    ↓                                                             │
│  ✅ Ressources GCP créées                                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GIT                                           │
│  gitops/infrastructure/controllers/crossplane/                   │
│  ├─ namespace.yaml                                               │
│  ├─ serviceaccount.yaml (avec annotation)                        │
│  ├─ helmrelease.yaml                                             │
│  ├─ provider-gcp.yaml                                            │
│  └─ providerconfig-gcp.yaml (projectID)                          │
│                                                                  │
│  git push                                                        │
│    ↓                                                             │
│  ✅ Fichiers dans Git                                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXCD                                        │
│  Détecte les changements → Applique les manifests               │
│    ↓                                                             │
│  ✅ Ressources K8s créées                                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  namespace: crossplane-system                            │  │
│  │  ├─ ServiceAccount: crossplane (annotation WI)           │  │
│  │  ├─ Deployment: crossplane                               │  │
│  │  ├─ Provider: provider-gcp                                │  │
│  │  └─ ProviderConfig: default                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│    ↓                                                             │
│  ✅ Crossplane opérationnel                                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UTILISATION                                   │
│  Développeur crée Bucket YAML → Git push                        │
│    ↓                                                             │
│  FluxCD sync → Bucket créé dans K8s                             │
│    ↓                                                             │
│  Crossplane détecte → Crée bucket sur GCP                       │
│    ↓                                                             │
│  ✅ Bucket disponible !                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎓 Points clés à retenir

### 1. **Workload Identity = Pas de clés**

Au lieu de stocker des clés JSON dans des Secrets, on utilise Workload Identity qui lie automatiquement le ServiceAccount Kubernetes au ServiceAccount GCP.

### 2. **Tout est déclaratif**

Comme Kubernetes, Crossplane fonctionne de manière déclarative :
- Vous décrivez **ce que vous voulez** (YAML)
- Crossplane fait **ce qu'il faut** pour l'obtenir

### 3. **Réconciliation continue**

Crossplane vérifie régulièrement que l'état réel correspond à l'état désiré. Si quelqu'un supprime un bucket manuellement, Crossplane le recrée.

### 4. **GitOps natif**

Crossplane fonctionne parfaitement avec FluxCD car tout est du YAML Kubernetes. Le workflow est :
```
Git → FluxCD → Kubernetes → Crossplane → GCP
```

### 5. **Self-service contrôlé**

Les développeurs peuvent créer des ressources, mais dans un cadre défini par l'équipe Platform (via RBAC, Compositions, etc.).

---

## 🔍 Pour aller plus loin

- [Documentation officielle Crossplane](https://docs.crossplane.io/)
- [Provider GCP](https://marketplace.upbound.io/providers/upbound/provider-gcp)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

---

**🎉 Félicitations !** Vous comprenez maintenant comment Crossplane fonctionne de A à Z !

