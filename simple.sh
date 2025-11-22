#!/bin/bash

cd ~/job-board

echo "=========================================="
echo "FIXING RESOURCE-PATCH.YAML"
echo "=========================================="

echo ""
echo "Step 1: Updating resource-patch.yaml with accessModes..."
cat > kubernetes/overlays/dev/resource-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
      - name: backend
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  template:
    spec:
      containers:
      - name: frontend
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 256Mi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  template:
    spec:
      containers:
      - name: postgres
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp3
      resources:
        requests:
          storage: 5Gi
EOF

echo ""
echo "Step 2: Testing kustomize build..."
kustomize build kubernetes/overlays/dev > /tmp/test.yaml

if grep -A 10 "volumeClaimTemplates:" /tmp/test.yaml | grep -q "ReadWriteOnce"; then
  echo "✅ accessModes present in build!"
else
  echo "❌ accessModes still missing in build!"
  echo "Showing volumeClaimTemplates section:"
  grep -A 15 "volumeClaimTemplates:" /tmp/test.yaml
  exit 1
fi

echo ""
echo "Step 3: Committing and pushing..."
git add kubernetes/overlays/dev/resource-patch.yaml
git commit -m "fix: Add accessModes and storageClassName to postgres volumeClaimTemplates patch"
git push origin main

echo ""
echo "Step 4: Cleaning up old resources..."
kubectl delete statefulset postgres -n job-board 2>/dev/null
kubectl delete pvc postgres-data-postgres-0 -n job-board 2>/dev/null

echo ""
echo "Step 5: Forcing ArgoCD sync..."
kubectl patch application job-board -n argocd --type merge -p '{"operation":{"sync":{}}}'

echo ""
echo "Step 6: Waiting for deployment (90 seconds)..."
sleep 90

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
kubectl get all -n job-board
echo ""
kubectl get pvc -n job-board

echo ""
if kubectl get pod postgres-0 -n job-board >/dev/null 2>&1; then
  STATUS=$(kubectl get pod postgres-0 -n job-board -o jsonpath='{.status.phase}')
  echo "🎉 postgres-0 EXISTS! Status: $STATUS"
  
  if [ "$STATUS" = "Running" ]; then
    echo ""
    echo "✅✅✅ SUCCESS! ALL PODS RUNNING! ✅✅✅"
    kubectl get pods -n job-board
  fi
else
  echo "⚠️ postgres-0 not created yet"
  kubectl describe statefulset postgres -n job-board | tail -20
fi
