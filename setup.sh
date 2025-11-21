#!/bin/bash

cd ~/job-board

echo "=========================================="
echo "FIXING MERGE CONFLICTS"
echo "=========================================="

# Fix dev
echo "Fixing dev kustomization..."
cat > kubernetes/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: job-board-dev
resources:
  - ../../base
images:
  - name: backend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-backend
    newTag: dev-4f3ae51
  - name: frontend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-frontend
    newTag: dev-4f3ae51
configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - ENVIRONMENT=development
      - LOG_LEVEL=debug
      - NODE_ENV=development
commonAnnotations:
  environment: dev
  managed-by: argocd
labels:
  - includeSelectors: true
    pairs:
      environment: dev
patches:
  - path: replica-patch.yaml
  - path: resource-patch.yaml
EOF

# Fix staging
echo "Fixing staging kustomization..."
cat > kubernetes/overlays/staging/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: job-board-staging
resources:
  - ../../base
images:
  - name: backend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-backend
    newTag: staging-8d6563c
  - name: frontend-placeholder
    newName: 180048382895.dkr.ecr.eu-west-2.amazonaws.com/job-board-frontend
    newTag: staging-8d6563c
configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - ENVIRONMENT=staging
      - LOG_LEVEL=info
      - NODE_ENV=production
commonAnnotations:
  environment: staging
  managed-by: argocd
labels:
  - includeSelectors: true
    pairs:
      environment: staging
patches:
  - path: replica-patch.yaml
  - path: resource-patch.yaml
EOF

# Validate
echo ""
echo "Validating..."
kustomize build kubernetes/overlays/dev > /dev/null && echo "✅ Dev valid"
kustomize build kubernetes/overlays/staging > /dev/null && echo "✅ Staging valid"

# Commit
echo ""
echo "Committing..."
git add kubernetes/overlays/*/kustomization.yaml
git commit -m "fix: Resolve merge conflicts in kustomization files"

# Push
echo ""
echo "Pushing to develop..."
git checkout develop
git push origin develop

echo ""
echo "Pushing to main..."
git checkout main
git merge develop
git push origin main

# Sync
echo ""
echo "Syncing ArgoCD..."
kubectl patch application job-board-dev -n argocd --type merge -p '{"operation":{"sync":{}}}'
kubectl patch application job-board-staging -n argocd --type merge -p '{"operation":{"sync":{}}}'

sleep 60

echo ""
echo "Restarting pods..."
kubectl delete pods --all -n job-board-dev
kubectl delete pods --all -n job-board-staging

sleep 30

echo ""
echo "=========================================="
echo "STATUS"
echo "=========================================="
kubectl get applications -n argocd
echo ""
kubectl get pods -n job-board-dev
echo ""
kubectl get pods -n job-board-staging
