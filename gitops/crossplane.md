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

#### Option A : Workload Identity (Recommandé)

```bash
# 1. Créer un Service Account GCP
gcloud iam service-accounts create crossplane-sa \
  --display-name="Crossplane Service Account"

# 2. Donner les permissions nécessaires
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:crossplane-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# 3. Lier au ServiceAccount Kubernetes
gcloud iam service-accounts add-iam-policy-binding \
  crossplane-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[crossplane-system/crossplane]"
```

#### Option B : Service Account Key (Pour lab)

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

### Étape 3 : Mettre à jour le ProviderConfig

```yaml
# gitops/infrastructure/controllers/crossplane/providerconfig-gcp.yaml
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: crossplane-system
spec:
  projectID: kkgcplabs01-032  # ⬅️ Remplacer par votre project_id
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-credentials
      key: credentials
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

