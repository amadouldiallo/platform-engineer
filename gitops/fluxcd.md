# 📚 FluxCD pour Débutants

> Guide pédagogique basé sur la Brique 2 du POC Platform Engineer

## 🎯 Qu'est-ce que FluxCD ?

**FluxCD** est un outil de **GitOps** pour Kubernetes. Il synchronise automatiquement l'état de votre cluster avec ce qui est défini dans un dépôt Git.

### Le principe GitOps

```
┌─────────────────┐                    ┌─────────────────┐
│                 │   git push         │                 │
│   Développeur   │ ─────────────────▶ │   Git (GitHub)  │
│                 │                    │                 │
└─────────────────┘                    └────────┬────────┘
                                                │
                                                │ pull (every 1min)
                                                ▼
                                       ┌─────────────────┐
                                       │                 │
                                       │  FluxCD dans    │
                                       │  Kubernetes     │
                                       │                 │
                                       └────────┬────────┘
                                                │
                                                │ kubectl apply
                                                ▼
                                       ┌─────────────────┐
                                       │                 │
                                       │  Cluster K8s    │
                                       │  (état désiré)  │
                                       │                 │
                                       └─────────────────┘
```

### GitOps vs CI/CD traditionnel

| Aspect | CI/CD Traditionnel | GitOps (FluxCD) |
|--------|-------------------|-----------------|
| Qui déploie ? | Pipeline CI/CD (push) | Cluster lui-même (pull) |
| Source de vérité | Pipeline/Scripts | Dépôt Git |
| Rollback | Relancer un pipeline | `git revert` |
| Audit | Logs du CI/CD | Historique Git |
| Sécurité | CI a accès au cluster | Cluster a accès à Git |

---

## 🧩 Les composants de FluxCD

FluxCD est composé de plusieurs **controllers** qui travaillent ensemble :

```
┌─────────────────────────────────────────────────────────────────┐
│                    Namespace: flux-system                        │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │ source-controller│    │ kustomize-       │                   │
│  │                  │    │ controller       │                   │
│  │ • GitRepository  │───▶│                  │───▶ Manifests K8s │
│  │ • HelmRepository │    │ • Kustomization  │                   │
│  │ • Bucket (S3)    │    │                  │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │ helm-controller  │    │ notification-    │                   │
│  │                  │    │ controller       │                   │
│  │ • HelmRelease    │    │                  │                   │
│  │                  │    │ • Alerts         │                   │
│  │                  │    │ • Providers      │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │ image-automation │  (optionnel)                              │
│  │ controller       │                                           │
│  │                  │                                           │
│  │ • ImagePolicy    │                                           │
│  │ • ImageUpdate    │                                           │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Rôle de chaque controller

| Controller | Rôle | CRDs |
|------------|------|------|
| **source-controller** | Télécharge les sources (Git, Helm, S3) | GitRepository, HelmRepository, Bucket |
| **kustomize-controller** | Applique les manifests Kubernetes | Kustomization |
| **helm-controller** | Installe/met à jour les charts Helm | HelmRelease |
| **notification-controller** | Envoie des alertes (Slack, Teams...) | Alert, Provider |
| **image-automation** | Met à jour les tags d'images automatiquement | ImagePolicy, ImageUpdateAutomation |

---

## 📦 Les Custom Resources (CRDs)

FluxCD utilise des **Custom Resources** Kubernetes. Voici les plus importants :

### 1️⃣ GitRepository

Définit un dépôt Git à surveiller :

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-gitops      # Nom de la ressource
  namespace: flux-system     # Toujours dans flux-system
spec:
  interval: 1m               # Vérifie les changements toutes les minutes
  url: https://github.com/USER/platform-engineer  # URL du dépôt
  ref:
    branch: main             # Branche à suivre
  secretRef:
    name: github-token       # Secret contenant le token (si privé)
```

**Ce que ça fait** : Le source-controller clone ce dépôt et le garde à jour.

---

### 2️⃣ Kustomization

Définit quels manifests appliquer depuis une source :

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure       # Nom de cette configuration
  namespace: flux-system
spec:
  interval: 10m              # Réconcilie toutes les 10 minutes
  sourceRef:
    kind: GitRepository
    name: platform-gitops    # Référence au GitRepository
  path: ./gitops/infrastructure  # Chemin dans le dépôt
  prune: true                # Supprime les ressources orphelines
  wait: true                 # Attend que les ressources soient prêtes
  timeout: 5m
```

**Ce que ça fait** : Applique tous les manifests YAML dans le dossier spécifié.

> ⚠️ **Ne pas confondre** avec `kustomization.yaml` (fichier Kustomize) !

---

### 3️⃣ HelmRepository

Définit un dépôt de charts Helm :

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ingress-nginx        # Nom du repo
  namespace: flux-system
spec:
  interval: 1h               # Rafraîchit l'index toutes les heures
  url: https://kubernetes.github.io/ingress-nginx  # URL du repo Helm
```

**Ce que ça fait** : Télécharge l'index du dépôt Helm pour trouver les charts.

---

### 4️⃣ HelmRelease

Définit une installation de chart Helm :

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx   # Namespace où installer
spec:
  interval: 15m              # Vérifie les mises à jour
  chart:
    spec:
      chart: ingress-nginx   # Nom du chart
      version: "4.x"         # Version (avec contraintes)
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: flux-system
  values:                    # Values du chart Helm
    controller:
      replicaCount: 1
      service:
        type: LoadBalancer
```

**Ce que ça fait** : Équivalent de `helm install ingress-nginx ingress-nginx/ingress-nginx`

---

## 🔄 Le flux de réconciliation

Voici comment FluxCD synchronise votre cluster :

```
1. PULL        2. DETECT       3. APPLY        4. REPORT
   │              │               │               │
   ▼              ▼               ▼               ▼
┌──────┐      ┌──────┐        ┌──────┐        ┌──────┐
│ Git  │ ───▶ │ Diff │ ───▶   │ K8s  │ ───▶   │Status│
│ Repo │      │  ?   │        │Apply │        │ OK/  │
└──────┘      └──────┘        └──────┘        │Error │
                                              └──────┘
   │              │               │               │
   │              │               │               │
   └──────────────┴───────────────┴───────────────┘
                        │
                   interval: 1m
                        │
                        ▼
                   Recommencer
```

### États possibles

| État | Signification |
|------|---------------|
| `Ready: True` | Tout est synchronisé ✅ |
| `Ready: False` | Erreur de réconciliation ❌ |
| `Suspended: True` | Réconciliation pausée ⏸️ |
| `Stalled` | En attente d'une dépendance |

---

## 📁 Structure recommandée

Voici la structure GitOps que nous utilisons :

```
gitops/
├── clusters/                    # Un dossier par cluster/environnement
│   └── dev/
│       ├── flux-system/         # Généré par flux bootstrap
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml
│       │   └── kustomization.yaml
│       ├── infrastructure.yaml  # Pointe vers /infrastructure
│       └── apps.yaml            # Pointe vers /apps
│
├── infrastructure/              # Composants partagés (infra)
│   ├── controllers/
│   │   ├── ingress-nginx/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── helmrepository.yaml
│   │   │   └── helmrelease.yaml
│   │   └── cert-manager/
│   │       └── ...
│   ├── monitoring/
│   │   └── prometheus/
│   │       └── ...
│   └── kustomization.yaml       # Agrège tous les sous-dossiers
│
└── apps/                        # Applications métier
    ├── base/                    # Définitions de base
    │   └── my-app/
    └── overlays/                # Surcharges par environnement
        └── dev/
```

### Pourquoi cette structure ?

1. **Séparation des concerns** : infrastructure vs applications
2. **Réutilisabilité** : base + overlays pour multi-environnements
3. **Ordre de déploiement** : infrastructure avant apps

---

## 🚀 Bootstrap de FluxCD

Le bootstrap est l'installation initiale de FluxCD dans le cluster :

```bash
# Prérequis : être connecté au cluster
kubectl cluster-info

# Exporter le token GitHub
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Bootstrap FluxCD
flux bootstrap github \
  --owner=MON_USERNAME \
  --repository=platform-engineer \
  --path=gitops/clusters/dev \
  --personal
```

### Ce que fait le bootstrap

1. ✅ Crée le namespace `flux-system`
2. ✅ Installe les controllers FluxCD
3. ✅ Crée un deploy key dans GitHub (pour accès au repo)
4. ✅ Crée les fichiers dans `gitops/clusters/dev/flux-system/`
5. ✅ Commit et push ces fichiers
6. ✅ Configure FluxCD pour surveiller ce dossier

---

## 🛠️ Commandes utiles

### Vérifier l'état de FluxCD

```bash
# Statut général
flux check

# Voir toutes les ressources Flux
flux get all

# Voir les GitRepositories
flux get sources git

# Voir les Kustomizations
flux get kustomizations

# Voir les HelmReleases
flux get helmreleases -A
```

### Forcer une réconciliation

```bash
# Réconcilier un GitRepository
flux reconcile source git platform-gitops

# Réconcilier une Kustomization
flux reconcile kustomization infrastructure

# Réconcilier un HelmRelease
flux reconcile helmrelease ingress-nginx -n ingress-nginx
```

### Suspendre/Reprendre

```bash
# Suspendre (pause les mises à jour)
flux suspend kustomization infrastructure

# Reprendre
flux resume kustomization infrastructure
```

### Debug

```bash
# Logs du source-controller
kubectl logs -n flux-system deploy/source-controller

# Logs du kustomize-controller
kubectl logs -n flux-system deploy/kustomize-controller

# Logs du helm-controller
kubectl logs -n flux-system deploy/helm-controller

# Events récents
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

---

## 📊 Dépendances entre ressources

FluxCD gère les dépendances automatiquement :

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
spec:
  dependsOn:
    - name: infrastructure    # Attend que infrastructure soit Ready
  # ...
```

Visualisation des dépendances :

```
                    ┌─────────────────┐
                    │   flux-system   │
                    │  (controllers)  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                              ▼
    ┌─────────────────┐           ┌─────────────────┐
    │  infrastructure │           │   sources       │
    │  (kustomization)│           │ (GitRepository) │
    └────────┬────────┘           └─────────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌──────────┐   ┌──────────┐
│ ingress  │   │ cert-mgr │
│ nginx    │   │          │
└──────────┘   └──────────┘
             │
             ▼
    ┌─────────────────┐
    │      apps       │
    │ (dépend de infra│
    └─────────────────┘
```

---

## 🔐 Gestion des secrets

FluxCD ne stocke PAS les secrets en clair dans Git. Options :

### Option 1 : Sealed Secrets

```bash
# Installer sealed-secrets
# Chiffrer un secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
# Seul le cluster peut déchiffrer
```

### Option 2 : SOPS + Age

```bash
# Créer une clé Age
age-keygen -o age.key

# Chiffrer avec SOPS
sops --encrypt --age $(cat age.key | grep public | cut -d: -f2) \
  secret.yaml > secret.enc.yaml
```

### Option 3 : External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: gcp-secret-manager
  target:
    name: my-secret
  data:
    - secretKey: password
      remoteRef:
        key: my-gcp-secret
```

---

## 🎓 Exercices pratiques

### Exercice 1 : Comprendre un HelmRelease

1. Ouvrez `gitops/infrastructure/controllers/ingress-nginx/helmrelease.yaml`
2. Identifiez :
   - Quel chart est installé ?
   - Dans quel namespace ?
   - Quelles values sont configurées ?

### Exercice 2 : Forcer une réconciliation

```bash
# Modifier un fichier dans Git, puis :
flux reconcile kustomization infrastructure --with-source

# Observer les logs
flux logs --follow
```

### Exercice 3 : Ajouter un nouveau composant

1. Créer un dossier `gitops/infrastructure/controllers/mon-app/`
2. Ajouter `kustomization.yaml`, `namespace.yaml`, `helmrelease.yaml`
3. Référencer dans `gitops/infrastructure/kustomization.yaml`
4. Commit et push
5. Observer le déploiement automatique

---

## ❓ FAQ

### Quelle différence entre Kustomization (Flux) et kustomization.yaml (Kustomize) ?

| Kustomization (CRD Flux) | kustomization.yaml (Kustomize) |
|--------------------------|--------------------------------|
| Ressource Kubernetes | Fichier de config |
| Définit QUOI appliquer | Définit COMMENT assembler |
| `apiVersion: kustomize.toolkit.fluxcd.io` | Pas d'apiVersion |

### Comment faire un rollback ?

```bash
# Option 1 : Git revert
git revert HEAD
git push

# Option 2 : Suspendre et appliquer manuellement
flux suspend kustomization apps
kubectl rollout undo deployment/my-app
```

### Comment exclure un fichier de la sync ?

Dans le `kustomization.yaml` Kustomize :
```yaml
resources:
  - deployment.yaml
  # - secret.yaml  # Commenté = non inclus
```

---

## 📚 Ressources

| Ressource | Lien |
|-----------|------|
| Documentation officielle | https://fluxcd.io/docs/ |
| Flux CLI Reference | https://fluxcd.io/flux/cmd/ |
| Exemples officiels | https://github.com/fluxcd/flux2-kustomize-helm-example |
| Flux Components | https://fluxcd.io/flux/components/ |
| GitOps Toolkit | https://fluxcd.io/flux/components/ |

---

## 🗺️ Récapitulatif de notre configuration

```yaml
# Ce que nous allons créer :

# 1. GitRepository - Source du dépôt
GitRepository/platform-gitops → github.com/USER/platform-engineer

# 2. Kustomization - Infrastructure
Kustomization/infrastructure → gitops/infrastructure/
  ├── ingress-nginx (HelmRelease)
  ├── cert-manager (HelmRelease)
  └── prometheus (HelmRelease)

# 3. Kustomization - Apps (Brique 4)
Kustomization/apps → gitops/apps/
  └── (à venir)
```

---

> 💡 **Conseil** : GitOps = "Git est la source de vérité". Si quelqu'un modifie le cluster manuellement (`kubectl edit`), FluxCD remettra l'état du Git au prochain cycle de réconciliation !

