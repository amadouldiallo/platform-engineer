# 🔮 Crossplane - Provisioning Cloud depuis Kubernetes

> **BRIQUE 3** du POC Platform Engineer

Crossplane permet de provisionner des ressources cloud (GCS, CloudSQL, Pub/Sub, etc.) directement depuis Kubernetes en utilisant des fichiers YAML.

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                  │
│  ┌────────────────┐     ┌────────────────┐                      │
│  │    FluxCD      │────▶│   Crossplane   │                      │
│  │ (GitOps sync)  │     │  (Cloud API)   │                      │
│  └────────────────┘     └───────┬────────┘                      │
│                                 │                                │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
            ┌──────────────┐           ┌──────────────┐
            │  GCS Bucket  │           │  CloudSQL   │
            │   (Storage)  │           │  (Database) │
            └──────────────┘           └──────────────┘
```

## 🏗️ Composants

### 1. Crossplane Core

| Composant | Description |
|-----------|-------------|
| **Crossplane** | Contrôleur principal qui réconcilie les ressources |
| **Provider GCP** | Plugin pour créer des ressources GCP |
| **ProviderConfig** | Configuration d'authentification GCP |

### 2. Ressources Crossplane

| Type | Description | Exemple |
|------|-------------|---------|
| **Managed Resource** | Ressource cloud unitaire | `Bucket`, `CloudSQLInstance` |
| **Composition** | Template combinant plusieurs ressources | `PostgresDatabase` (DB + Secret) |
| **Claim** | Interface simplifiée pour les devs | `PostgresDatabase` (abstraction) |

## 📁 Structure des fichiers

```
gitops/
├── infrastructure/
│   └── controllers/
│       └── crossplane/
│           ├── namespace.yaml
│           ├── helmrepository.yaml
│           ├── helmrelease.yaml
│           ├── provider-gcp.yaml
│           └── providerconfig-gcp.yaml
│
└── apps/
    └── examples/
        └── gcs-bucket-example.yaml  # Exemple de bucket GCS
```

## 🚀 Installation

### Étape 1 : Vérifier que Crossplane est installé

```bash
# Vérifier les pods
kubectl get pods -n crossplane-system

# Vérifier le Provider GCP
kubectl get provider -n crossplane-system

# Vérifier le ProviderConfig
kubectl get providerconfig -n crossplane-system
```

### Étape 2 : Configurer l'authentification GCP

> ⚠️ **Note Lab** : Les projets lab GCP n'ont pas les permissions `iam.serviceAccounts.create`.
>    On utilise donc l'**Option B (Service Account Key)** au lieu de Workload Identity.

#### Option A : Workload Identity avec Terraform (Production)

> ⚠️ **Non disponible dans les projets lab** - Permissions IAM insuffisantes

Cette option est désactivée dans Terraform pour les projets lab. Voir l'Option B ci-dessous.

#### Option B : Service Account Key (Projets Lab)

> ✅ **Utilisé dans les projets lab** - Création manuelle du Service Account

```bash
# 1. Aller dans le dossier infra
cd infra

# 2. Vérifier le plan Terraform
terraform plan

# 3. Appliquer les changements
#    Cela crée :
#    - Service Account GCP (crossplane-sa)
#    - Permissions IAM (Storage, SQL, Pub/Sub)
#    - Workload Identity Binding
terraform apply

# 4. Mettre à jour les fichiers Crossplane avec les valeurs réelles
./update-crossplane-config.sh

# 5. Vérifier les fichiers modifiés
git diff ../gitops/infrastructure/controllers/crossplane/

# 6. Commit et push
git add ../gitops/infrastructure/controllers/crossplane/
git commit -m "chore(crossplane): update config with terraform outputs"
git push
```

#### Ce que Terraform crée automatiquement

| Ressource | Description |
|-----------|-------------|
| **Service Account GCP** | `crossplane-sa@PROJECT_ID.iam.gserviceaccount.com` |
| **IAM Roles** | `storage.admin`, `cloudsql.admin`, `pubsub.admin` |
| **Workload Identity Binding** | Lien SA GCP ↔ SA Kubernetes |

#### Vérification

```bash
# Vérifier le Service Account créé
terraform output crossplane_service_account_email

# Vérifier dans GCP
gcloud iam service-accounts list | grep crossplane
```

#### Procédure pour projets lab (Service Account Key)

```bash
# 1. Créer un Service Account GCP (via console ou gcloud si permissions OK)
gcloud iam service-accounts create crossplane-sa \
  --display-name="Crossplane Service Account" \
  --project=PROJECT_ID

# Si erreur de permissions, créer via la console GCP :
# https://console.cloud.google.com/iam-admin/serviceaccounts

# 2. Donner les permissions nécessaires
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:crossplane-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:crossplane-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:crossplane-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.admin"

# 3. Créer une clé JSON
gcloud iam service-accounts keys create key.json \
  --iam-account=crossplane-sa@PROJECT_ID.iam.gserviceaccount.com

# 4. Créer le Secret Kubernetes
kubectl create secret generic gcp-credentials \
  --from-file=credentials=key.json \
  -n crossplane-system

# 5. Mettre à jour providerconfig-gcp.yaml
# Voir la section "Configuration ProviderConfig" ci-dessous
```

```bash
# 1. Créer un Service Account
gcloud iam service-accounts create crossplane-sa \
  --display-name="Crossplane Service Account"

# 2. Donner les permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:crossplane-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# 3. Créer une clé
gcloud iam service-accounts keys create key.json \
  --iam-account=crossplane-sa@PROJECT_ID.iam.gserviceaccount.com

# 4. Créer le Secret Kubernetes
kubectl create secret generic gcp-credentials \
  --from-file=credentials=key.json \
  -n crossplane-system

# 5. Mettre à jour providerconfig-gcp.yaml
# Décommenter la section "Option 2: Service Account Key"
```

### Étape 3 : Vérifier la configuration

```bash
# Vérifier que le ProviderConfig est correct
kubectl get providerconfig default -n crossplane-system -o yaml

# Vérifier que le ServiceAccount Kubernetes a l'annotation
kubectl get serviceaccount crossplane -n crossplane-system -o yaml | grep iam.gke.io

# Vérifier que le Provider GCP est prêt
kubectl get provider provider-gcp -n crossplane-system
```

## 📝 Exemples d'utilisation

### Exemple 1 : Créer un Bucket GCS

```yaml
apiVersion: storage.gcp.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-app-bucket
  namespace: default
spec:
  forProvider:
    location: US-CENTRAL1
    storageClass: STANDARD
    versioning:
      - enabled: true
    labels:
      team: backend
      environment: dev
  
  writeConnectionSecretToRef:
    name: bucket-credentials
    namespace: default
```

**Résultat** :
- ✅ Bucket créé sur GCP
- ✅ Secret `bucket-credentials` créé dans K8s avec les infos

### Exemple 2 : Utiliser le Secret dans un Pod

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: app
          env:
            - name: BUCKET_NAME
              valueFrom:
                secretKeyRef:
                  name: bucket-credentials
                  key: bucketName
```

## 🔧 Commandes utiles

### Vérifier les ressources Crossplane

```bash
# Voir tous les buckets créés
kubectl get buckets

# Détails d'un bucket
kubectl describe bucket my-app-bucket

# Voir les événements
kubectl get events --sort-by='.lastTimestamp' | grep crossplane
```

### Logs Crossplane

```bash
# Logs du contrôleur Crossplane
kubectl logs -n crossplane-system deploy/crossplane

# Logs du Provider GCP
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-gcp
```

### Supprimer une ressource

```bash
# Supprimer le bucket (et le Secret associé)
kubectl delete bucket my-app-bucket

# Crossplane supprime automatiquement la ressource sur GCP
```

## 🔐 Sécurité et Restrictions

### RBAC : Limiter les permissions

```yaml
# Les devs peuvent créer des Buckets, mais pas des CloudSQL
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crossplane-user
  namespace: team-alpha
rules:
  - apiGroups: ["storage.gcp.upbound.io"]
    resources: ["buckets"]
    verbs: ["get", "list", "create", "delete"]
  # Pas d'accès à sql.gcp.upbound.io !
```

### ResourceQuota : Limiter le nombre

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: crossplane-limits
  namespace: team-alpha
spec:
  hard:
    count/buckets.storage.gcp.upbound.io: "5"
```

## 🚨 Troubleshooting

### Provider pas prêt

```bash
# Vérifier le statut
kubectl get provider provider-gcp -n crossplane-system

# Si pas prêt, voir les logs
kubectl describe provider provider-gcp -n crossplane-system
```

### Erreur d'authentification

```bash
# Vérifier le ProviderConfig
kubectl get providerconfig default -n crossplane-system -o yaml

# Vérifier le Secret
kubectl get secret gcp-credentials -n crossplane-system
```

### Ressource bloquée en "Creating"

```bash
# Voir les détails
kubectl describe bucket my-bucket

# Voir les événements
kubectl get events --field-selector involvedObject.name=my-bucket
```

## 📚 Documentation

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Provider GCP](https://marketplace.upbound.io/providers/upbound/provider-gcp)
- [Managed Resources GCP](https://docs.crossplane.io/latest/concepts/managed-resources/)

---

## ➡️ Prochaines étapes

1. ✅ **Installer Crossplane** (fait)
2. ✅ **Configurer Provider GCP** (à faire)
3. ✅ **Tester avec un Bucket** (exemple fourni)
4. **Créer des Compositions** (templates réutilisables)
5. **Passer à la BRIQUE 4** — Microservice

