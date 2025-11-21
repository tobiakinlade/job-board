#!/bin/bash

cd ~/job-board

echo "=========================================="
echo "SIMPLIFYING TO SINGLE BRANCH/ENVIRONMENT"
echo "=========================================="

# Switch to main
git checkout main

# Delete staging overlay
rm -rf kubernetes/overlays/staging

# Create simplified ArgoCD app
cat > argocd/applications.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: job-board
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tobiakinlade/job-board.git
    targetRevision: main
    path: kubernetes/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: job-board
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Delete old workflows, create new one
rm -f .github/workflows/backend-ci.yml .github/workflows/frontend-ci.yml

# [Paste the deploy.yml content from above here]

# Clean kustomization
cat > kubernetes/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: job-board
resources:
  - ../../base
images:
  - name: backend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-backend
    newTag: latest
  - name: frontend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-frontend
    newTag: latest
patches:
  - path: replica-patch.yaml
  - path: resource-patch.yaml
EOF

# Clean up Kubernetes
kubectl delete application job-board-dev job-board-staging -n argocd 2>/dev/null
kubectl delete namespace job-board-dev job-board-staging 2>/dev/null

# Apply new setup
kubectl apply -f argocd/applications.yaml
kubectl create namespace job-board 2>/dev/null
kubectl create secret generic job-board-secrets \
  --from-literal=postgres-database=jobboard \
  --from-literal=postgres-user=jobboard_user \
  --from-literal=postgres-password=password123 \
  -n job-board 2>/dev/null

# Commit
git add -A
git commit -m "refactor: Simplify to single branch and environment"
git push origin main
git push origin --delete develop 2>/dev/null

echo ""
echo "✅ SIMPLIFIED!"
echo "- One branch: main"
echo "- One environment: job-board"
echo "- One workflow: deploy.yml"
