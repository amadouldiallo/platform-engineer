# 🔄 GitOps avec FluxCD

> **BRIQUE 2** du POC Platform Engineer

Ce module configure FluxCD pour gérer l'état du cluster Kubernetes via GitOps.

## 📊 Configuration du Cluster

| Ressource | Valeur |
|-----------|--------|
| **Nodes** | 3 x e2-medium |
| **Total CPU** | 6 vCPU |
| **Total RAM** | 12 GB |
| **Autoscaling** | ❌ Désactivé (cost control) |
| **Zone** | us-central1-a |

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GitHub: platform-engineer                            │
│                                                                              │
│  gitops/                                                                     │
│  ├── clusters/dev/          ←── Point d'entrée FluxCD                       │
│  ├── infrastructure/        ←── Ingress, Cert-Manager, Prometheus           │
│  └── apps/                  ←── Applications (Brique 4)                     │
│                                                                              │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 │ Sync every 1 minute
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      GKE Cluster: platform-cluster                           │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                      flux-system namespace                               ││
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            ││
│  │  │source-controller│  │kustomize-ctrl │  │ helm-controller│            ││
│  │  └────────────────┘  └────────────────┘  └────────────────┘            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │  ingress-nginx  │  │   cert-manager  │  │   monitoring    │             │
│  │   (Ingress)     │  │  (Certificats)  │  │  (Prometheus)   │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📁 Structure des fichiers

```
gitops/
├── README.md                    # 📖 Cette documentation
├── fluxcd.md                    # 📚 Guide FluxCD pour débutants
│
├── clusters/                    # Configuration par cluster
│   └── dev/
│       ├── flux-system/         # 🤖 Auto-généré par flux bootstrap
│       ├── infrastructure.yaml  # Pointe vers /infrastructure
│       └── apps.yaml            # Pointe vers /apps
│
├── infrastructure/              # Composants d'infrastructure
│   ├── kustomization.yaml       # Liste tous les composants
│   ├── controllers/
│   │   ├── ingress-nginx/       # Ingress Controller
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── helmrepository.yaml
│   │   │   └── helmrelease.yaml
│   │   └── cert-manager/        # Gestion des certificats TLS
│   │       └── ...
│   └── monitoring/
│       └── kube-prometheus-stack/  # Prometheus + Grafana
│           └── ...
│
└── apps/                        # Applications métier (Brique 4)
    ├── kustomization.yaml
    └── .gitkeep
```

## 🚀 Installation

### Prérequis

| Outil | Version | Installation |
|-------|---------|--------------|
| Flux CLI | >= 2.0 | `curl -s https://fluxcd.io/install.sh \| sudo bash` |
| kubectl | Latest | `gcloud components install kubectl` |
| GitHub Token | - | [Créer un token](https://github.com/settings/tokens) avec scope `repo` |

### Étape 1 : Vérifier le cluster

```bash
# S'assurer d'être connecté au bon cluster
kubectl cluster-info
kubectl get nodes

# Vérifier que Flux CLI est installé
flux --version
```

### Étape 2 : Exporter le token GitHub

```bash
# Créer un token sur https://github.com/settings/tokens
# Scope requis: repo (full control)

export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
export GITHUB_USER=votre-username
```

### Étape 3 : Bootstrap FluxCD

```bash
# Bootstrap FluxCD dans le cluster
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=platform-engineer \
  --branch=main \
  --path=gitops/clusters/dev \
  --personal
```

Cette commande va :
1. ✅ Créer le namespace `flux-system`
2. ✅ Installer les controllers FluxCD
3. ✅ Créer un deploy key dans votre repo GitHub
4. ✅ Créer les manifests dans `gitops/clusters/dev/flux-system/`
5. ✅ Configurer la synchronisation automatique

### Étape 4 : Vérifier l'installation

```bash
# Vérifier que Flux est opérationnel
flux check

# Voir les ressources Flux
flux get all

# Attendre que l'infrastructure soit déployée
flux get kustomizations --watch
```

## 📦 Composants déployés

> ⚠️ **Note Lab** : Les ressources sont optimisées pour un cluster 3x e2-medium (6 vCPU, 12GB RAM)

### 1. Ingress-Nginx Controller

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `ingress-nginx` |
| Chart | `ingress-nginx/ingress-nginx` |
| Version | `4.x` |
| Service | LoadBalancer (IP externe GCP) |
| CPU Request | 50m |
| Memory Request | 64Mi |

```bash
# Vérifier l'ingress
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Obtenir l'IP externe
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 2. Cert-Manager

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `cert-manager` |
| Chart | `jetstack/cert-manager` |
| Version | `1.x` |
| CPU Request | 25m (controller) |
| Memory Request | 32Mi (controller) |

```bash
# Vérifier cert-manager
kubectl get pods -n cert-manager

# Vérifier les CRDs
kubectl get crds | grep cert-manager
```

### 3. Kube-Prometheus-Stack

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `monitoring` |
| Chart | `prometheus-community/kube-prometheus-stack` |
| Version | `55.x` |
| Grafana password | `admin` (à changer !) |
| Prometheus CPU | 50m request |
| Grafana CPU | 25m request |
| Retention | 24h / 1GB |

```bash
# Vérifier le monitoring
kubectl get pods -n monitoring

# Accéder à Grafana (port-forward)
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Ouvrir http://localhost:3000 (admin/admin)

# Accéder à Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Ouvrir http://localhost:9090
```

### 4. FluxCD Controllers

| Controller | CPU Request | Memory Request |
|------------|-------------|----------------|
| source-controller | 25m | 48Mi |
| kustomize-controller | 25m | 48Mi |
| helm-controller | 25m | 48Mi |
| notification-controller | 25m | 48Mi |

> Ces valeurs sont optimisées dans `gitops/clusters/dev/flux-system/gotk-components.yaml`

## 🔧 Commandes utiles

### FluxCD

```bash
# Statut général
flux check
flux get all

# Voir les sources Git
flux get sources git

# Voir les Kustomizations
flux get kustomizations

# Voir les HelmReleases
flux get helmreleases -A

# Forcer une réconciliation
flux reconcile kustomization infrastructure --with-source

# Voir les logs
flux logs --follow

# Suspendre/Reprendre
flux suspend kustomization infrastructure
flux resume kustomization infrastructure
```

### Debug

```bash
# Logs des controllers
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller
kubectl logs -n flux-system deploy/helm-controller

# Events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Décrire une ressource en erreur
kubectl describe helmrelease ingress-nginx -n ingress-nginx
```

## 🔄 Workflow GitOps

### Modifier une configuration

```bash
# 1. Modifier un fichier (ex: augmenter les replicas)
vim gitops/infrastructure/controllers/ingress-nginx/helmrelease.yaml

# 2. Commit et push
git add .
git commit -m "chore(ingress): increase replicas to 2"
git push

# 3. Attendre la réconciliation (ou forcer)
flux reconcile kustomization infrastructure --with-source

# 4. Vérifier
kubectl get pods -n ingress-nginx
```

### Ajouter un nouveau composant

1. Créer un dossier dans `infrastructure/` ou `apps/`
2. Ajouter les fichiers `kustomization.yaml`, `namespace.yaml`, `helmrelease.yaml`
3. Référencer dans le `kustomization.yaml` parent
4. Commit et push

### Rollback

```bash
# Git est la source de vérité
git revert HEAD
git push

# FluxCD appliquera automatiquement le revert
```

## 🚨 Troubleshooting

### ⚠️ Problèmes résolus dans ce POC

#### 1. HelmRepository dans mauvais namespace
**Problème** : Le `namespace:` dans `kustomization.yaml` override tous les namespaces, y compris HelmRepository qui doit être dans `flux-system`.

**Solution** : Retirer `namespace:` du kustomization et définir le namespace explicitement dans chaque ressource.

```yaml
# ❌ MAUVAIS - override le namespace de toutes les ressources
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ingress-nginx  # Ceci override aussi HelmRepository !

# ✅ BON - pas de namespace global
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml        # namespace: ingress-nginx
  - helmrepository.yaml   # namespace: flux-system
  - helmrelease.yaml      # namespace: ingress-nginx
```

#### 2. Ressources insuffisantes sur e2-medium
**Problème** : 1 node e2-medium (2 vCPU) saturé par les pods système GKE.

**Solution** : 
- Passer à 3 nodes (6 vCPU total)
- Réduire les requests FluxCD (25m CPU par controller)
- Réduire les requests Prometheus/Grafana

### HelmRelease stuck in "Not Ready"

```bash
# Voir les détails
kubectl describe helmrelease <name> -n <namespace>

# Vérifier les logs du helm-controller
kubectl logs -n flux-system deploy/helm-controller | grep <name>
```

### Kustomization failed

```bash
# Voir l'erreur
flux get kustomization infrastructure

# Détails
kubectl describe kustomization infrastructure -n flux-system
```

### Source not found

```bash
# Vérifier le GitRepository
flux get sources git

# Réconcilier
flux reconcile source git flux-system
```

## 📊 Monitoring de FluxCD

FluxCD expose des métriques Prometheus :

```bash
# Voir les métriques
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring

# Requêtes PromQL utiles :
# - gotk_reconcile_condition (état des réconciliations)
# - gotk_reconcile_duration_seconds (durée)
```

## 🔐 Sécurité

### Secrets

Les secrets ne doivent **JAMAIS** être en clair dans Git. Options :

1. **Sealed Secrets** : Chiffrement côté client
2. **SOPS + Age** : Chiffrement avec clé Age
3. **External Secrets** : Synchronisation depuis Secret Manager

### RBAC

FluxCD utilise un ServiceAccount avec les permissions minimales nécessaires.

## 📚 Documentation

- [Guide FluxCD pour débutants](./fluxcd.md)
- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Flux CLI Reference](https://fluxcd.io/flux/cmd/)

---

## ✅ État actuel

| Composant | Version | Status |
|-----------|---------|--------|
| FluxCD | v2.7.5 | ✅ Running |
| ingress-nginx | 4.14.1 | ✅ Running |
| cert-manager | v1.19.1 | ✅ Running |
| kube-prometheus-stack | 55.11.0 | ✅ Running |

### IP Externe Ingress
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## ➡️ Prochaines étapes

1. ~~**Bootstrap FluxCD** dans votre cluster~~ ✅
2. ~~**Vérifier** que l'infrastructure est déployée~~ ✅
3. **Passer à la BRIQUE 3** — Crossplane (provisioning cloud depuis K8s)
4. **Passer à la BRIQUE 4** — Microservice (ajoutera des apps dans `gitops/apps/`)

