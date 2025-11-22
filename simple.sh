#!/bin/bash

cd ~/job-board

echo "=========================================="
echo "COMPLETE FIX - FORCE CORRECT STORAGECLASS"
echo "=========================================="

echo ""
echo "Step 1: Updating local files to ebs-gp3..."
sed -i '' 's/storageClassName: gp3/storageClassName: ebs-gp3/g' kubernetes/overlays/dev/resource-patch.yaml
sed -i '' 's/storageClassName: gp3/storageClassName: ebs-gp3/g' kubernetes/base/postgres-statefulset.yaml

echo ""
echo "Verifying:"
grep storageClassName kubernetes/overlays/dev/resource-patch.yaml
grep storageClassName kubernetes/base/postgres-statefulset.yaml

echo ""
echo "Step 2: Committing and pushing..."
git add kubernetes/
git commit -m "fix: Use ebs-gp3 StorageClass (not gp3)" 2>/dev/null || echo "Already committed"
git push origin main

echo ""
echo "Step 3: Force deleting old PVC..."
kubectl patch pvc postgres-data-postgres-0 -n job-board -p '{"metadata":{"finalizers":null}}' 2>/dev/null
kubectl delete pvc postgres-data-postgres-0 -n job-board --force --grace-period=0 2>/dev/null

echo ""
echo "Step 4: Deleting StatefulSet..."
kubectl delete statefulset postgres -n job-board 2>/dev/null

echo ""
echo "Step 5: Deleting and recreating ArgoCD application..."
kubectl delete application job-board -n argocd
sleep 5
kubectl apply -f argocd/applications.yaml

echo ""
echo "Step 6: Recreating secret..."
kubectl delete secret job-board-secrets -n job-board 2>/dev/null
kubectl create secret generic job-board-secrets \
  --from-literal=DB_HOST=postgres \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=jobboard \
  --from-literal=DB_USER=jobboard_user \
  --from-literal=DB_PASSWORD=secure_password_123 \
  --from-literal=POSTGRES_DB=jobboard \
  --from-literal=POSTGRES_USER=jobboard_user \
  --from-literal=POSTGRES_PASSWORD=secure_password_123 \
  -n job-board

echo ""
echo "Step 7: Waiting for full deployment (120 seconds)..."
sleep 120

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
kubectl get all -n job-board
echo ""
kubectl get pvc -n job-board

echo ""
PVC_SC=$(kubectl get pvc postgres-data-postgres-0 -n job-board -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
if [ "$PVC_SC" = "ebs-gp3" ]; then
  echo "✅ PVC using correct StorageClass: ebs-gp3"
  PVC_STATUS=$(kubectl get pvc postgres-data-postgres-0 -n job-board -o jsonpath='{.status.phase}')
  echo "PVC Status: $PVC_STATUS"
else
  echo "❌ PVC still using wrong StorageClass: $PVC_SC"
fi

echo ""
RUNNING=$(kubectl get pods -n job-board --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "Pods Running: $RUNNING / 3"

if [ "$RUNNING" -eq 3 ]; then
  echo ""
  echo "🎉🎉🎉 SUCCESS! ALL PODS RUNNING! 🎉🎉🎉"
  kubectl get pods -n job-board
fi
