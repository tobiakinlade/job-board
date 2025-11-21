#!/bin/bash

echo "=========================================="
echo "ARGOCD APPLICATION SETUP"
echo "=========================================="

cd ~/job-board

echo ""
echo "Step 1: Applying ArgoCD applications..."
kubectl apply -f argocd/applications.yaml

echo ""
echo "Step 2: Checking application status..."
kubectl get applications -n argocd

echo ""
echo "Step 3: Force syncing applications..."
kubectl patch application job-board-dev -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"develop"}}}'

kubectl patch application job-board-staging -n argocd \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'

echo ""
echo "Step 4: Waiting for sync (90 seconds)..."
sleep 90

echo ""
echo "Step 5: Checking namespaces..."
kubectl get namespaces | grep job-board

# If namespaces don't exist after sync, create manually
if ! kubectl get namespace job-board-dev &>/dev/null; then
  echo "⚠️ Dev namespace not created by ArgoCD, creating manually..."
  kubectl create namespace job-board-dev
fi

if ! kubectl get namespace job-board-staging &>/dev/null; then
  echo "⚠️ Staging namespace not created by ArgoCD, creating manually..."
  kubectl create namespace job-board-staging
fi

echo ""
echo "Step 6: Creating secrets..."
kubectl create secret generic job-board-secrets \
  --from-literal=postgres-database=jobboard \
  --from-literal=postgres-user=jobboard_user \
  --from-literal=postgres-password=dev_password_123 \
  -n job-board-dev 2>/dev/null && echo "✅ Dev secret created" || echo "⚠️ Dev secret already exists or failed"

kubectl create secret generic job-board-secrets \
  --from-literal=postgres-database=jobboard \
  --from-literal=postgres-user=jobboard_user \
  --from-literal=postgres-password=staging_password_456 \
  -n job-board-staging 2>/dev/null && echo "✅ Staging secret created" || echo "⚠️ Staging secret already exists or failed"

echo ""
echo "Step 7: Final sync to deploy all resources..."
kubectl patch application job-board-dev -n argocd \
  --type merge \
  --patch '{"operation":{"sync":{}}}'

kubectl patch application job-board-staging -n argocd \
  --type merge \
  --patch '{"operation":{"sync":{}}}'

echo ""
echo "Step 8: Waiting for deployment (60 seconds)..."
sleep 60

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="

echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd

echo ""
echo "Dev Namespace Resources:"
kubectl get all -n job-board-dev

echo ""
echo "Staging Namespace Resources:"
kubectl get all -n job-board-staging

echo ""
echo "Dev Secrets:"
kubectl get secrets -n job-board-dev

echo ""
echo "Staging Secrets:"
kubectl get secrets -n job-board-staging

echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo "If pods show ImagePullBackOff:"
echo "1. Check images exist in ECR"
echo "2. Check kustomization files have correct tags"
echo "3. Trigger workflows to build images"
echo "4. Delete old pods: kubectl delete pods --all -n job-board-dev"
