#!/bin/bash

echo "=========================================="
echo "COMPLETE POSTGRES FIX"
echo "=========================================="

echo ""
echo "Step 1: Update secret with ALL key variations..."
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

echo "✅ Secret created with both DB_* and POSTGRES_* keys"

echo ""
echo "Step 2: Delete StatefulSet (forces recreation)..."
kubectl delete statefulset postgres -n job-board

echo ""
echo "Step 3: Delete any stuck PVCs..."
kubectl delete pvc postgres-data-postgres-0 -n job-board 2>/dev/null

echo ""
echo "Step 4: Verify local file is correct..."
cd ~/job-board
if grep -A 5 "volumeClaimTemplates:" kubernetes/base/postgres-statefulset.yaml | grep -q "ReadWriteOnce"; then
  echo "✅ Local file has accessModes"
else
  echo "❌ Fixing local file..."
  cat > kubernetes/base/postgres-statefulset.yaml <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: job-board-secrets
              key: POSTGRES_DB
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: job-board-secrets
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: job-board-secrets
              key: POSTGRES_PASSWORD
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - jobboard_user
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - jobboard_user
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: init-script
        configMap:
          name: postgres-init-script
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
  git add kubernetes/base/postgres-statefulset.yaml
  git commit -m "fix: Use POSTGRES_* keys and ensure accessModes"
  git push origin main
fi

echo ""
echo "Step 5: Delete and recreate ArgoCD application..."
kubectl delete application job-board -n argocd
sleep 5
kubectl apply -f argocd/applications.yaml

echo ""
echo "Step 6: Waiting for deployment (90 seconds)..."
sleep 90

echo ""
echo "=========================================="
echo "FINAL CHECK"
echo "=========================================="
kubectl get all -n job-board
echo ""
kubectl get pvc -n job-board

echo ""
if kubectl get pod postgres-0 -n job-board >/dev/null 2>&1; then
  STATUS=$(kubectl get pod postgres-0 -n job-board -o jsonpath='{.status.phase}')
  echo "✅ postgres-0 pod exists! Status: $STATUS"
  
  if [ "$STATUS" != "Running" ]; then
    echo ""
    echo "Pod details:"
    kubectl describe pod postgres-0 -n job-board | tail -30
  fi
else
  echo "❌ postgres-0 not created yet"
  kubectl describe statefulset postgres -n job-board | tail -30
fi
